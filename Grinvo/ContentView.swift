//
//  ContentView.swift
//  Grinvo
//
//  Created by Diego Lopes on 13/11/25.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    // State
    @State private var selectedMonthYearIndex: Int
    @State private var hourlyRate = "15"
    @State private var nomadFeePct = "1.0"
    @State private var higlobeFeePct = "0.3"
    @State private var fxRateOverride = ""
    @State private var result: WorkHoursResult?
    @State private var isLoading = false

    // Dependencies
    private let calculator = WorkHoursCalculator()
    private let calendar = Calendar.current
    
    private static let monthNames = [
        "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
        "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
    ]
    
    private var years: [Int] {
        let currentYear = calendar.component(.year, from: Date())
        return [currentYear - 1, currentYear, currentYear + 1]
    }
    
    private var selectedMonthDate: Date {
        guard monthYearOptions.indices.contains(selectedMonthYearIndex) else {
            return Date()
        }
        return monthYearOptions[selectedMonthYearIndex].date
    }
    
    private var monthYearOptions: [(label: String, date: Date)] {
        ContentView.buildMonthYearOptions(calendar: calendar, years: years)
    }
    
    private var selectedMonthYearLabel: String {
        guard monthYearOptions.indices.contains(selectedMonthYearIndex) else {
            return "Período selecionado"
        }
        return monthYearOptions[selectedMonthYearIndex].label
    }
    
    private static func buildMonthYearOptions(
        calendar: Calendar,
        years: [Int]
    ) -> [(label: String, date: Date)] {
        var options: [(label: String, date: Date)] = []
        
        for year in years {
            for month in 1...12 {
                guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
                    continue
                }
                let label = "\(Self.monthNames[month - 1]) - \(year)"
                options.append((label: label, date: date))
            }
        }
        
        return options.sorted { $0.date > $1.date }
    }
    
    init() {
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let years = [year - 1, year, year + 1]
        let options = ContentView.buildMonthYearOptions(calendar: calendar, years: years)
        let defaultIndex = options.firstIndex {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month) &&
            calendar.isDate($0.date, equalTo: now, toGranularity: .year)
        } ?? 0
        _selectedMonthYearIndex = State(initialValue: defaultIndex)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    Section(header: Text("Mês da fatura")) {
                        HStack {
                            Text("Mês - Ano")
                            Spacer()
                            Picker(selection: $selectedMonthYearIndex) {
                                ForEach(Array(monthYearOptions.enumerated()), id: \.offset) { index, option in
                                    Text(option.label).tag(index)
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

                    Section(header: Text("Taxas de saque")) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nomad / Husky (%)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Percentual descontado pela Nomad/Husky ao enviar BRL")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            TextField("Ex: 1.0", text: $nomadFeePct)
                                .applyDecimalKeyboard()
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("HiGlobe (%)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Percentual descontado pela HiGlobe ao enviar BRL")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            TextField("Ex: 0.3", text: $higlobeFeePct)
                                .applyDecimalKeyboard()
                        }
                    }

                    Section {
                        Button("Gerar fatura") {
                            hideKeyboard()
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
                            Text("Fatura de \(selectedMonthYearLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ResultTableView(result: result)
                                .id("result")
                        }
                    }
                }
                .onChange(of: result) { oldValue, newValue in
                    if newValue != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                proxy.scrollTo("result", anchor: .top)
                            }
                        }
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
            let nomadFeePctValue = Double(nomadFeePct),
            let higlobeFeePctValue = Double(higlobeFeePct)
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
            nomadFeePct: nomadFeePctValue,
            higlobeFeePct: higlobeFeePctValue,
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
    
    func hideKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

// MARK: - Result Table View

struct ResultTableView: View {
    let result: WorkHoursResult
    
    private static let brlFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        return formatter
    }()
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        // Use template to get locale-appropriate format
        let template = "ddMMyyyyEEE"
        if let dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: Locale.current) {
            formatter.dateFormat = dateFormat
        } else {
            // Fallback format
            formatter.dateFormat = "dd/MM/yyyy (EEE)"
        }
        return formatter
    }
    
    private func formatCurrencyBRL(_ value: Double) -> String {
        let isNegative = value < 0
        let absoluteValue = abs(value)
        let formatted = ResultTableView.brlFormatter.string(from: NSNumber(value: absoluteValue)) ?? String(format: "%.2f", absoluteValue)
        let prefix = isNegative ? "-R$" : "R$"
        return "\(prefix) \(formatted)"
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
                    
                    TableRow(label: "BRL convertido", value: formatCurrencyBRL(result.conversionGrossBrl), isHighlighted: true)
                }
                
                if let nomadFees = result.nomadFeesBrl,
                   let nomadNet = result.nomadNetBrl {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nomad / Husky (\(String(format: "%.2f", result.nomadFeePct))%)")
                            .font(.headline)
                        
                        TableRow(label: "Taxas", value: formatCurrencyBRL(-nomadFees))
                        TableRow(label: "Líquido", value: formatCurrencyBRL(nomadNet), isHighlighted: true)
                    }
                }
                
                if let higlobeFees = result.higlobeFeesBrl,
                   let higlobeNet = result.higlobeNetBrl {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HiGlobe (\(String(format: "%.2f", result.higlobeFeePct))%)")
                            .font(.headline)
                        
                        TableRow(label: "Taxas", value: formatCurrencyBRL(-higlobeFees))
                        TableRow(label: "Líquido", value: formatCurrencyBRL(higlobeNet), isHighlighted: true)
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
