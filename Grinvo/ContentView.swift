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
    @State private var hourlyRate = "15"
    @State private var spreadPct = "1.0"
    @State private var withdrawFeePct = "0.0"
    @State private var withdrawFeeBrl = "0.0"
    @State private var iofPct = "0.0"
    @State private var fxRateOverride = ""
    @State private var fxLabelOverride = ""
    @State private var resultText = ""
    @State private var isLoading = false

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
                
                Section(header: Text("Taxa de Câmbio (Opcional)")) {
                    TextField("Taxa FX manual (BRL/USD)", text: $fxRateOverride)
                        .applyDecimalKeyboard()
                    TextField("Label da taxa manual", text: $fxLabelOverride)
                        .placeholder(when: fxLabelOverride.isEmpty) {
                            Text("Manual override")
                        }
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
                        Task {
                            await generateInvoice()
                        }
                    }
                    .disabled(isLoading)
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Buscando taxa de câmbio...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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

    private func generateInvoice() async {
        guard
            let hourlyRateValue = Double(hourlyRate),
            let spreadValue = Double(spreadPct),
            let withdrawFeePctValue = Double(withdrawFeePct),
            let withdrawFeeBrlValue = Double(withdrawFeeBrl),
            let iofPctValue = Double(iofPct)
        else {
            await MainActor.run {
                resultText = "Valores de entrada inválidos."
            }
            return
        }
        
        // Parse FX override if provided
        let fxRateOverrideValue: Double? = fxRateOverride.isEmpty ? nil : Double(fxRateOverride)
        let fxLabelOverrideValue: String? = fxLabelOverride.isEmpty ? nil : fxLabelOverride

        await MainActor.run {
            isLoading = true
        }
        
        let options = WorkHoursOptions(
            month: selectedMonth,
            hourlyRate: hourlyRateValue,
            spreadPct: spreadValue,
            withdrawFeePct: withdrawFeePctValue,
            withdrawFeeBrl: withdrawFeeBrlValue,
            iofPct: iofPctValue,
            fxRate: fxRateOverrideValue,
            fxLabel: fxLabelOverrideValue,
            mode: .both,
            includeXmasEve: true
        )

        let result = await calculator.calculate(options: options)
        
        await MainActor.run {
            resultText = result.summaryText
            isLoading = false
        }
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
    
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    ContentView()
}
