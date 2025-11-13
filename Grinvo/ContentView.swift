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
    @StateObject private var viewModel = InvoiceViewModel()
    @FocusState private var focusedField: Field?
    @State private var selectedTab: Tab = .home
    
    private enum Field: Hashable {
        case hourlyRate
        case fxRate
        case nomadFee
        case higlobeFee
    }

    private var homeContent: some View {
        Form {
            Section(header: Text("Mês da fatura")) {
                HStack {
                    Text("Mês - Ano")
                    Spacer()
                    Picker(selection: $viewModel.selectedMonthYearIndex) {
                        ForEach(Array(viewModel.monthYearOptions.enumerated()), id: \.offset) { index, option in
                            Text(option.label).tag(index)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.menu)
                }
            }

            Section(header: Text("Valor Hora")) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Valor hora em USD", text: $viewModel.hourlyRate)
                        .applyDecimalKeyboard()
                        .focused($focusedField, equals: .hourlyRate)
                        .font(.headline)
                    if let displayValue = viewModel.formattedHourlyRate {
                        Text(displayValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                    TextField("Ex: 5.40", text: $viewModel.fxRateOverride)
                        .applyDecimalKeyboard()
                        .focused($focusedField, equals: .fxRate)
                }
            }

            Section(header: Text("Taxas de saque")) {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: $viewModel.isNomadEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nomad / Husky")
                                .font(.caption)
                                .foregroundStyle(.primary)
                            Text("Percentual descontado pela Nomad/Husky ao enviar BRL")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    TextField("Ex: 1.0", text: $viewModel.nomadFeePct)
                        .applyDecimalKeyboard()
                        .disabled(!viewModel.isNomadEnabled)
                        .focused($focusedField, equals: .nomadFee)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: $viewModel.isHiglobeEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HiGlobe")
                                .font(.caption)
                                .foregroundStyle(.primary)
                            Text("Percentual descontado pela HiGlobe ao enviar BRL")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    TextField("Ex: 0.3", text: $viewModel.higlobeFeePct)
                        .applyDecimalKeyboard()
                        .disabled(!viewModel.isHiglobeEnabled)
                        .focused($focusedField, equals: .higlobeFee)
                }
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            focusedField = nil
        })
        .safeAreaPadding(.bottom, 140)
    }
    
    private enum Tab: String, CaseIterable {
        case home
        case result
        
        var title: String {
            switch self {
            case .home: return "Principal"
            case .result: return "Resumo"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .result: return "banknote"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                TabView(selection: $selectedTab) {
                    homeContent
                        .tag(Tab.home)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .background(Color(.systemBackground))
                    
                    resultContent
                        .tag(Tab.result)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .background(Color(.systemGroupedBackground))
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
                
                VStack(spacing: 12) {
                    tabBar
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Grinvo - by Diego L.")
                            .font(.headline)
                        Text("Gringo + Invoice")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: selectedTab) { newValue in
                focusedField = nil
                hideKeyboard()
                if newValue == .result {
                    viewModel.handleResultTabAppear()
                }
            }
        }
    }

    private var resultContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Calculando saque...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                if let result = viewModel.result {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Último cálculo")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Período: \(viewModel.selectedMonthYearLabel)")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    ResultTableView(result: result)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Nenhum cálculo ainda")
                            .font(.headline)
                        Text("Use a aba Principal para informar os dados e abra esta aba para calcular o saque.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .simultaneousGesture(TapGesture().onEnded {
            focusedField = nil
        })
        .safeAreaPadding(.bottom, 140)
    }

    private var tabBar: some View {
        HStack(spacing: 16) {
            tabBarItem(for: .home)
            tabBarItem(for: .result)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    @ViewBuilder
    private func tabBarItem(for tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = tab
                focusedField = nil
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .imageScale(.medium)
                Text(tab.title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.clear)
            )
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
    
    private struct PayoutEntry: Identifiable {
        let title: String
        let feePct: Double
        let fees: Double
        let net: Double
        
        var id: String { title }
    }
    
    private enum Medal {
        case gold
        case silver
        
        var symbolName: String { "medal.fill" }
        var color: Color {
            switch self {
            case .gold: return .yellow
            case .silver: return .gray
            }
        }
        
        var accessibilityLabel: String {
            switch self {
            case .gold: return "Medalha de ouro"
            case .silver: return "Medalha de prata"
            }
        }
    }
    
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
    
    private var payoutEntries: [PayoutEntry] {
        var entries: [PayoutEntry] = []
        if let fees = result.nomadFeesBrl, let net = result.nomadNetBrl {
            entries.append(PayoutEntry(title: "Nomad / Husky", feePct: result.nomadFeePct, fees: fees, net: net))
        }
        if let fees = result.higlobeFeesBrl, let net = result.higlobeNetBrl {
            entries.append(PayoutEntry(title: "HiGlobe", feePct: result.higlobeFeePct, fees: fees, net: net))
        }
        return entries
    }
    
    private var medalAssignments: [String: Medal] {
        let sorted = payoutEntries.sorted { $0.net > $1.net }
        var assignments: [String: Medal] = [:]
        if let first = sorted.first {
            assignments[first.title] = .gold
        }
        if sorted.count > 1 {
            assignments[sorted[1].title] = .silver
        }
        return assignments
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
                    
                    if let asOf = result.fxAsOf {
                        TableRow(label: "Taxa FX", value: String(format: "%.4f BRL/USD", fxRate))
                        TableRow(label: "Atualizado em", value: asOf)
                    }
                    
                    TableRow(label: "BRL convertido", value: formatCurrencyBRL(result.conversionGrossBrl), isHighlighted: true)
                }
                
                ForEach(payoutEntries) { entry in
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("\(entry.title) (\(String(format: "%.2f", entry.feePct))%)")
                                .font(.headline)
                            if let medal = medalAssignments[entry.title] {
                                Image(systemName: medal.symbolName)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(medal.color)
                                    .accessibilityLabel(Text(medal.accessibilityLabel))
                            }
                        }
                        
                        TableRow(label: "Taxas", value: formatCurrencyBRL(-entry.fees))
                        TableRow(label: "Líquido", value: formatCurrencyBRL(entry.net), isHighlighted: true)
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
