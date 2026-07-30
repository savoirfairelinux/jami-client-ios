/*
 *  Copyright (C) 2004-2026 Savoir-faire Linux Inc.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

/**
 * The page's side of the bridge to the application.
 *
 * WKWebView has no equivalent of addJavascriptInterface: the page posts to a
 * message handler and Swift reads it. This puts that behind the same
 * `window.JamiBridge` the editor expects, so the editor itself does not have
 * to know which platform it is running on.
 */

const handler = window.webkit
    && window.webkit.messageHandlers
    && window.webkit.messageHandlers.jami

if (handler) {
    const send = (name) => (...args) => handler.postMessage({ name, args })
    window.JamiBridge = {
        onReady: send('onReady'),
        onUpdate: send('onUpdate'),
        onAwareness: send('onAwareness'),
        onSelection: send('onSelection'),
        onLog: send('onLog'),
    }
}
