//
//  ContentView.swift
//  Grinvo
//
//  Created by Diego Lopes on 13/11/25.
//

import SwiftUI

struct ContentView: View {
    // State
    @State private var selectedYear: Int
    @State private var selectedMonthIndex: Int
    @State private var hourlyRate = "15"
    @State private var spreadPct = "1.0"
    @State private var withdrawFeePct = "0.0"
    @State private var withdrawFeeBrl = "0.0"
    @State private var iofPct = "0.0"
    @State private var fxRateOverride = ""
    @State private var resultText = ""
    @State private var isLoading = false

    // Dependencies
    private let calculator = WorkHoursCalculator()
    private let calendar = Calendar.current
    
    private let monthNames = [
        "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
        "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
    ]
    
    private var years: [Int] {
        let currentYear = calendar.component(.year, from: Date())
        return [currentYear - 1, currentYear, currentYear + 1]
    }
    
    private var selectedMonthDate: Date {
        calendar.date(from: DateComponents(year: selectedYear, month: selectedMonthIndex + 1, day: 1)) ?? Date()
    }
    
    init() {
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        _selectedYear = State(initialValue: year)
        _selectedMonthIndex = State(initialValue: month - 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Mês da fatura")) {
                    HStack {
                        Text("Mês")
                        Spacer()
                        Picker(selection: $selectedMonthIndex) {
                            ForEach(0..<12) { index in
                                Text(monthNames[index]).tag(index)
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.menu)
                    }
                    
                    HStack {
                        Text("Ano")
                        Spacer()
                        Picker(selection: $selectedYear) {
                            ForEach(years, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section(header: Text("Taxas")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Valor hora (USD/hora)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Ex: 15", text: $hourlyRate)
                            .applyDecimalKeyboard()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spread (%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Percentual deduzido após conversão USD→BRL")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("Ex: 1.0", text: $spreadPct)
                            .applyDecimalKeyboard()
                    }
                }
                
                Section(header: Text("Taxa de Câmbio (Opcional)")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Taxa manual (BRL/USD)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Deixe vazio para buscar automaticamente via API")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("Ex: 5.40", text: $fxRateOverride)
                            .applyDecimalKeyboard()
                    }
                }

                Section(header: Text("Taxas de saque (opcional)")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Taxa percentual (%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Ex: 1.2", text: $withdrawFeePct)
                            .applyDecimalKeyboard()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Taxa fixa (BRL)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Ex: 7.90", text: $withdrawFeeBrl)
                            .applyDecimalKeyboard()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IOF / Taxa extra (%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Ex: 0.38", text: $iofPct)
                            .applyDecimalKeyboard()
                    }
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

        await MainActor.run {
            isLoading = true
        }
        
        let options = WorkHoursOptions(
            month: selectedMonthDate,
            hourlyRate: hourlyRateValue,
            spreadPct: spreadValue,
            withdrawFeePct: withdrawFeePctValue,
            withdrawFeeBrl: withdrawFeeBrlValue,
            iofPct: iofPctValue,
            fxRate: fxRateOverrideValue,
            fxLabel: nil, // Always use default "Manual override" label
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
