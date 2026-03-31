/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import os

#if DEBUG_TOOLS_ENABLED

import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterHttp
import OpenTelemetryProtocolExporterCommon

final class TelemetryService {
    static let shared = TelemetryService()

    private let queue = DispatchQueue(label: "cx.ring.jami.debugTools.telemetry")
    private let osLog = os.Logger(subsystem: "cx.ring.jami", category: "telemetry")

    private var tracer: Tracer?
    private var providerBuilt = false
    private var endpointURL: URL?
    private var processSource: String = "unknown"
    private var role: NotificationTesting.Role?
    private var configured = false

    typealias SpanHandle = String

    private init() {}

    // MARK: - Configuration

    func configure(
        appGroupIdentifier: String,
        endpointURL: URL?,
        role: NotificationTesting.Role?
    ) {
        queue.sync {
            let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
            let isExtension = bundleId.contains("Extension") || bundleId.contains("extension")
            self.processSource = isExtension ? "extension" : "app"
            self.endpointURL = endpointURL
            self.role = role
            self.configured = true
        }
    }

    func updateEndpoint(_ url: URL?) {
        queue.async {
            self.endpointURL = url
        }
    }

    func updateRole(_ newRole: NotificationTesting.Role) {
        queue.async { self.role = newRole }
    }

    // MARK: - Span API

    @discardableResult
    func emitInstantSpan(
        name: String,
        parentTraceparent: String? = nil,
        errorMessage: String? = nil,
        attributes: [String: String] = [:]
    ) -> String {
        return queue.sync {
            guard let tracer = buildTracerIfNeeded() else {
                return Self.syntheticTraceId()
            }
            let builder = tracer.spanBuilder(spanName: name)
            for (key, value) in attributes {
                builder.setAttribute(key: key, value: .string(value))
            }
            if let traceparent = parentTraceparent, let ctx = Self.parseTraceparent(traceparent) {
                builder.setParent(ctx)
            }
            let span = builder.startSpan()
            if let err = errorMessage {
                span.status = .error(description: err)
            }
            let traceId = span.context.traceId.hexString
            span.end()
            osLog.debug("[telemetry] instant span=\(name, privacy: .public) trace=\(traceId, privacy: .public)")
            return traceId
        }
    }

    func startSpan(
        name: String,
        parentTraceparent: String? = nil,
        attributes: [String: String] = [:]
    ) -> (handle: SpanHandle, traceparent: String) {
        return queue.sync {
            guard let tracer = buildTracerIfNeeded() else {
                let id = Self.syntheticTraceId()
                return (id, "00-\(id)-\(String(id.prefix(16)))-01")
            }
            let builder = tracer.spanBuilder(spanName: name)
            for (key, value) in attributes {
                builder.setAttribute(key: key, value: .string(value))
            }
            if let traceparent = parentTraceparent, let ctx = Self.parseTraceparent(traceparent) {
                builder.setParent(ctx)
            }
            let span = builder.startSpan()
            let traceId = span.context.traceId.hexString
            let spanId = span.context.spanId.hexString
            let flags = String(format: "%02x", span.context.traceFlags.byte)
            let traceparent = "00-\(traceId)-\(spanId)-\(flags)"

            let handle = UUID().uuidString
            activeSpans[handle] = span
            osLog.debug("[telemetry] start span=\(name, privacy: .public) trace=\(traceId, privacy: .public)")
            return (handle, traceparent)
        }
    }

    func endSpan(
        handle: SpanHandle,
        attributes: [String: String] = [:],
        errorMessage: String? = nil
    ) {
        queue.sync {
            guard let span = activeSpans.removeValue(forKey: handle) else { return }
            for (key, value) in attributes {
                span.setAttribute(key: key, value: .string(value))
            }
            if let err = errorMessage {
                span.status = .error(description: err)
            }
            span.end()
            osLog.debug("[telemetry] end span handle=\(handle.prefix(8), privacy: .public)")
        }
    }

    private var activeSpans: [String: Span] = [:]

    // MARK: - Daemon span ingestion

    func ingestDaemonSpans(json: String) {
        guard !json.isEmpty, json != "[]" else { return }
        guard let data = json.data(using: .utf8),
              let spans = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }
        queue.sync {
            guard let tracer = buildTracerIfNeeded() else { return }
            for spanData in spans {
                guard let name = spanData["name"] as? String,
                      let traceIdHex = spanData["traceId"] as? String,
                      let spanIdHex = spanData["spanId"] as? String else { continue }

                let parentHex = spanData["parentSpanId"] as? String ?? ""
                let startNano = spanData["startTimeUnixNano"] as? Int64
                    ?? Self.isoToNano(spanData["startTime"] as? String)
                let endNano = spanData["endTimeUnixNano"] as? Int64
                    ?? Self.isoToNano(spanData["endTime"] as? String)
                let statusCode = spanData["status"] as? Int ?? 0
                let attrs = spanData["attributes"] as? [String: Any] ?? [:]

                let builder = tracer.spanBuilder(spanName: "daemon.\(name)")
                builder.setAttribute(key: "daemon.traceId", value: .string(traceIdHex))
                builder.setAttribute(key: "daemon.spanId", value: .string(spanIdHex))
                if !parentHex.isEmpty && parentHex != "0000000000000000" {
                    builder.setAttribute(key: "daemon.parentSpanId", value: .string(parentHex))
                    if let ctx = Self.parseTraceparent("00-\(traceIdHex)-\(parentHex)-01") {
                        builder.setParent(ctx)
                    }
                }
                for (key, value) in attrs {
                    if let stringValue = value as? String {
                        builder.setAttribute(key: "daemon.\(key)", value: .string(stringValue))
                    } else if let intValue = value as? Int {
                        builder.setAttribute(key: "daemon.\(key)", value: .int(intValue))
                    } else if let boolValue = value as? Bool {
                        builder.setAttribute(key: "daemon.\(key)", value: .bool(boolValue))
                    }
                }
                if let startNanoseconds = startNano, startNanoseconds > 0 {
                    let startDate = Date(timeIntervalSince1970: Double(startNanoseconds) / 1_000_000_000)
                    builder.setStartTime(time: startDate)
                }
                if statusCode == 2 {
                    builder.setAttribute(key: "daemon.status", value: .string("error"))
                }
                let span = builder.startSpan()
                span.end(time: endNano.map({ $0 > 0 ? Date(timeIntervalSince1970: Double($0) / 1_000_000_000) : Date() })
                            ?? Date())
            }
            osLog.debug("[telemetry] ingested \(spans.count) daemon spans")
        }
    }

    // MARK: - Flush

    func flushPendingSpans(timeout: TimeInterval = 2.0) {
        let providerRef: TracerProviderSdk? = queue.sync {
            return OpenTelemetry.instance.tracerProvider as? TracerProviderSdk
        }
        providerRef?.forceFlush(timeout: timeout)
    }

    // MARK: - Private

    private func buildTracerIfNeeded() -> Tracer? {
        if providerBuilt { return tracer }

        guard let baseURL = endpointURL else {
            osLog.warning("[telemetry] no endpoint URL, spans dropped (configured=\(self.configured))")
            return nil
        }
        providerBuilt = true
        osLog.info("[telemetry] building TracerProvider with endpoint \(baseURL.absoluteString, privacy: .public)")
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        comps?.path = "/v1/traces"
        guard let tracesEndpoint = comps?.url else { return nil }

        let bundleVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
            ?? "unknown"
        let resource = Resource(attributes: [
            "service.name": .string("jami.ios.\(processSource)"),
            "service.version": .string(bundleVersion),
            "telemetry.sdk.language": .string("swift"),
            "role": .string(role?.rawValue ?? "unknown")
        ])

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.waitsForConnectivity = true
        sessionConfig.timeoutIntervalForRequest = 10
        sessionConfig.urlCache = nil
        let session = URLSession(configuration: sessionConfig)
        let httpClient = BaseHTTPClient(session: session)

        let exporterConfig = OtlpConfiguration(timeout: 5.0)
        let exporter = OtlpHttpTraceExporter(
            endpoint: tracesEndpoint,
            config: exporterConfig,
            httpClient: httpClient
        )

        let processor = SimpleSpanProcessor(spanExporter: exporter)

        let provider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .with(resource: resource)
            .build()

        OpenTelemetry.registerTracerProvider(tracerProvider: provider)

        let telemetryTracer = OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: "jami.ios.telemetry",
            instrumentationVersion: bundleVersion
        )
        tracer = telemetryTracer
        osLog.info("[telemetry] TracerProvider initialized, endpoint=\(tracesEndpoint.absoluteString, privacy: .public)")
        return telemetryTracer
    }

    static func parseTraceparent(_ traceparent: String) -> SpanContext? {
        let parts = traceparent.split(separator: "-", maxSplits: 3, omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        let traceIdHex = String(parts[1])
        let spanIdHex = String(parts[2])
        let flagsHex = String(parts[3])
        guard traceIdHex.count == 32, spanIdHex.count == 16 else { return nil }
        let traceId = TraceId(fromHexString: traceIdHex)
        let spanId = SpanId(fromHexString: spanIdHex)
        let flagsByte = UInt8(flagsHex, radix: 16) ?? 0
        let flags = TraceFlags(fromByte: flagsByte)
        return SpanContext.createFromRemoteParent(
            traceId: traceId,
            spanId: spanId,
            traceFlags: flags,
            traceState: TraceState()
        )
    }

    private static func syntheticTraceId() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func isoToNano(_ iso: String?) -> Int64? {
        guard let iso, !iso.isEmpty else { return nil }
        guard let date = isoFormatter.date(from: iso)
                ?? isoFormatterNoFrac.date(from: iso) else { return nil }
        return Int64(date.timeIntervalSince1970 * 1_000_000_000)
    }
}

#endif
