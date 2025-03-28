import SwiftUI

struct CallBannerView: View {
    @ObservedObject var viewModel: CallBannerViewModel
    
    var body: some View {
        if viewModel.isVisible {
            VStack(spacing: 0) {
                ForEach(viewModel.activeCalls, id: \.id) { call in
                    VStack(spacing: 12) {

                        Text ("A call is in progress. Do you want to join the call?")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 16) {
                            Button(action: {
                                viewModel.acceptVideoCall(for: call)
                            }) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.jamiColor)
                                    .padding(.horizontal)
                            }
                            
                            Button(action: {
                                viewModel.acceptAudioCall(for: call)
                            }) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.jamiColor)
                                    .padding(.horizontal)
                            }
                        }
                    }
//                    .padding(.horizontal, 16)
//                    .padding(.vertical, 12)
//                    .background(Color(UIColor.systemBackground))
//                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
            .cornerRadius(10)
            .shadow(radius: 5)
        }
    }
} 
