//
//  ContentView.swift
//  Grinvo
//
//  Created by Diego Lopes on 13/11/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedMonth = Date()
    @State private var hourlyRate = "18"
    @State private var spreadPct = "1.0"
    @State private var withdrawFeePct = "0.0"
    @State private var withdrawFeeBrl = "0.0"
    @State private var iofPct = "0.0"
    @State private var resultText = ""

    private let calculator = WorkHoursCalculator()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Invoice month")) {
                    DatePicker(
                        "Month",
                        selection: $selectedMonth,
                        displayedComponents: [.date]
                    )
                }

                Section(header: Text("Rates")) {
                    TextField("Hourly rate (USD/hour)", text: $hourlyRate)
                        .applyDecimalKeyboard()
                    TextField("Spread (%)", text: $spreadPct)
                        .applyDecimalKeyboard()
                }

                Section(header: Text("Withdraw fees")) {
                    TextField("Withdraw fee (%)", text: $withdrawFeePct)
                        .applyDecimalKeyboard()
                    TextField("Withdraw fixed fee (BRL)", text: $withdrawFeeBrl)
                        .applyDecimalKeyboard()
                    TextField("IOF / extra (%)", text: $iofPct)
                        .applyDecimalKeyboard()
                }

                Section {
                    Button("Generate invoice") {
                        generateInvoice()
                    }
                }

                if !resultText.isEmpty {
                    Section(header: Text("Result")) {
                        Text(resultText)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .navigationTitle("Grinvo")
        }
    }

    private func generateInvoice() {
        guard
            let hourlyRateValue = Double(hourlyRate),
            let spreadValue = Double(spreadPct),
            let withdrawFeePctValue = Double(withdrawFeePct),
            let withdrawFeeBrlValue = Double(withdrawFeeBrl),
            let iofPctValue = Double(iofPct)
        else {
            resultText = "Invalid input values."
            return
        }

        let options = WorkHoursOptions(
            month: selectedMonth,
            hourlyRate: hourlyRateValue,
            spreadPct: spreadValue,
            withdrawFeePct: withdrawFeePctValue,
            withdrawFeeBrl: withdrawFeeBrlValue,
            iofPct: iofPctValue,
            fxRate: Double?(nil),
            mode: WorkHoursOptions.Mode.both
        )

        let result = calculator.calculate(options: options)
        resultText = result.summaryText
    }
}

private extension View {
    @ViewBuilder
    func applyDecimalKeyboard() -> some View {
        #if os(iOS) || os(visionOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}

#Preview {
    ContentView()
}
