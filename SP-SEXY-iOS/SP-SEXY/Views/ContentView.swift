import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: GoogleAuth

    var body: some View {
        if auth.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            ReservationsView()
                .tabItem { Label("Rezerwacje", systemImage: "calendar") }
            FlightLogView()
                .tabItem { Label("Dziennik", systemImage: "list.bullet.rectangle.portrait") }
        }
        .tint(Config.pilots[0].color)
    }
}

/// Menu wylogowania (wspólne dla obu zakładek).
struct LogoutMenu: View {
    @EnvironmentObject var auth: GoogleAuth

    var body: some View {
        Menu {
            if let pilot = auth.pilot {
                Text(pilot.name)
            }
            Button(role: .destructive) {
                auth.signOut()
            } label: {
                Label("Wyloguj", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "person.crop.circle")
        }
    }
}
