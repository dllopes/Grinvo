//
//  ContentView.swift
//  Grinvo
//
//  Created by Diego Lopes on 13/11/25.
//

import SwiftUI

struct ContentView: View {
    // State
    @State private var selectedMonth = Date()
    @State private var hourlyRate = "18"
    @State private var spreadPct = "1.0"
    @State private var withdrawFeePct = "0.0"
    @State private var withdrawFeeBrl = "0.0"
    @State private var iofPct = "0.0"
    @State private var resultText = ""

    // Dependencies
    private let calculator = WorkHoursCalculator()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Mês da fatura")) {
                    DatePicker(
                        "Mês",
                        selection: $selectedMonth,
                        displayedComponents: [.date]
                    )
                }

                Section(header: Text("Taxas")) {
                    TextField("Valor hora (USD/hora)", text: $hourlyRate)
                        .applyDecimalKeyboard()
                    TextField("Spread (%)", text: $spreadPct)
                        .applyDecimalKeyboard()
                }

                Section(header: Text("Taxas de saque")) {
                    TextField("Taxa de saque (%)", text: $withdrawFeePct)
                        .applyDecimalKeyboard()
                    TextField("Taxa fixa de saque (BRL)", text: $withdrawFeeBrl)
                        .applyDecimalKeyboard()
                    TextField("IOF / extra (%)", text: $iofPct)
                        .applyDecimalKeyboard()
                }

                Section {
                    Button("Gerar fatura") {
                        generateInvoice()
                    }
                }

                if !resultText.isEmpty {
                    Section(header: Text("Resultado")) {
                        Text(resultText)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Grinvo - by Diego L.")
                            .font(.headline)
                        Text("Assistente de fatura mensal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func generateInvoice() {
        guard
            let hourlyRateValue = Double(hourlyRate),
            let spreadValue = Double(spreadPct),
            let withdrawFeePctValue = Double(withdrawFeePct),
            let withdrawFeeBrlValue = Double(withdrawFeeBrl),
            let iofPctValue = Double(iofPct)
        else {
            resultText = "Valores de entrada inválidos."
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
