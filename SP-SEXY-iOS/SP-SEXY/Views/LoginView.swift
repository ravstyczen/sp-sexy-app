import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: GoogleAuth

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(Config.pilots[0].color)

            VStack(spacing: 6) {
                Text("SP-SEXY")
                    .font(.largeTitle.bold())
                Text("Rezerwacje samolotu")
                    .foregroundStyle(.secondary)
            }

            if let err = auth.errorMessage {
                Text(err)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task { await auth.signIn() }
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Zaloguj przez Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .disabled(auth.isLoading)

            if auth.isLoading {
                ProgressView()
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}
