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
    @State private var result: WorkHoursResult?
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

                if let result = result {
                    Section(header: Text("Resultado")) {
                        ResultTableView(result: result)
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
                result = nil
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

        let calculatedResult = await calculator.calculate(options: options)
        
        await MainActor.run {
            result = calculatedResult
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

// MARK: - Result Table View

struct ResultTableView: View {
    let result: WorkHoursResult
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy (EEE)"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Horas trabalhadas
            VStack(alignment: .leading, spacing: 8) {
                Text("Horas Trabalhadas")
                    .font(.headline)
                
                TableRow(label: "Dias úteis", value: "\(result.workDays) dias (\(result.workHours)h)")
                TableRow(label: "Feriados pagos", value: "\(result.paidHolidays) dias (\(result.holidayHours)h)")
                TableRow(label: "Total de horas", value: "\(result.totalHours)h", isHighlighted: true)
            }
            
            Divider()
            
            // Valores em USD
            VStack(alignment: .leading, spacing: 8) {
                Text("Valores em USD")
                    .font(.headline)
                
                TableRow(label: "Taxa horária", value: String(format: "$%.2f USD/h", result.totalHours > 0 ? result.grossUsd / Double(result.totalHours) : 0))
                TableRow(label: "Valor total (USD)", value: String(format: "$%.2f", result.grossUsd), isHighlighted: true)
            }
            
            if let fxRate = result.fxRate {
                Divider()
                
                // Conversão BRL
                VStack(alignment: .leading, spacing: 8) {
                    Text("Conversão USD → BRL")
                        .font(.headline)
                    
                    if let source = result.fxSource, let asOf = result.fxAsOf {
                        TableRow(label: "Taxa FX", value: String(format: "%.4f BRL/USD", fxRate))
                        TableRow(label: "Fonte", value: "\(source)")
                        TableRow(label: "Data", value: asOf)
                    }
                    
                    TableRow(label: "BRL bruto", value: String(format: "R$ %.2f", result.conversionGrossBrl))
                    TableRow(label: "Spread (\(String(format: "%.2f", result.conversionGrossBrl > 0 ? result.spreadFeeBrl / result.conversionGrossBrl * 100 : 0))%)", value: String(format: "-R$ %.2f", result.spreadFeeBrl))
                    TableRow(label: "BRL líquido", value: String(format: "R$ %.2f", result.conversionNetBrl), isHighlighted: true)
                }
                
                // Taxas de saque (se aplicável)
                if let withdrawFees = result.withdrawFeesBrl, let withdrawNet = result.withdrawNetBrl {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Taxas de Saque")
                            .font(.headline)
                        
                        TableRow(label: "Total de taxas", value: String(format: "-R$ %.2f", withdrawFees))
                        TableRow(label: "Valor líquido final", value: String(format: "R$ %.2f", withdrawNet), isHighlighted: true)
                    }
                }
            } else {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Taxa de Câmbio")
                        .font(.headline)
                    
                    Text("Indisponível (offline ou erro na API)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Feriados do mês
            if !result.paidHolidayDates.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Feriados no Mês")
                        .font(.headline)
                    
                    ForEach(result.paidHolidayDates, id: \.self) { date in
                        Text(dateFormatter.string(from: date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct TableRow: View {
    let label: String
    let value: String
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(isHighlighted ? .headline : .body)
                .foregroundStyle(isHighlighted ? .primary : .primary)
        }
    }
}

#Preview {
    ContentView()
}
