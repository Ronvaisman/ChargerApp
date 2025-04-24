import SwiftUI

struct SettingsView: View {
    @AppStorage("electricityRate") private var electricityRate: Double = 0.6402
    @State private var rateString: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Electricity Rate")) {
                    HStack {
                        Text("Price per kWh")
                        Spacer()
                        TextField("Rate", text: $rateString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onAppear {
                                rateString = String(format: "%.4f", electricityRate)
                            }
                        Text("ILS")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Save Rate") {
                        if let newRate = Double(rateString) {
                            if newRate > 0 {
                                electricityRate = newRate
                                alertMessage = "Rate updated successfully"
                            } else {
                                alertMessage = "Rate must be greater than 0"
                            }
                        } else {
                            alertMessage = "Please enter a valid number"
                        }
                        showingAlert = true
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Default Rate")
                        Spacer()
                        Button("Reset to Default") {
                            electricityRate = 0.6402
                            rateString = "0.6402"
                            alertMessage = "Rate reset to default value"
                            showingAlert = true
                        }
                    }
                }
                
                Section(header: Text("Help")) {
                    Text("The electricity rate is used to calculate the cost of each charging session. The default rate is set to 0.6402 ILS per kWh as specified by the utility company.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .alert("Settings", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
} 