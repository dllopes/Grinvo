//
//  InvoiceViewModel.swift
//  Grinvo
//
//  Created by Diego Lopes on 13/11/25.
//

import Foundation
import Combine

@MainActor
final class InvoiceViewModel: ObservableObject {
    // MARK: - Published State
    @Published var selectedMonthYearIndex: Int {
        didSet { scheduleAutoCalculation() }
    }
    
    @Published var hourlyRate: String {
        didSet { scheduleAutoCalculation() }
    }
    
    @Published var nomadFeePct: String {
        didSet { scheduleAutoCalculation() }
    }
    
    @Published var higlobeFeePct: String {
        didSet { scheduleAutoCalculation() }
    }
    
    @Published var fxRateOverride: String {
        didSet { scheduleAutoCalculation() }
    }
    
    @Published var isNomadEnabled: Bool {
        didSet { scheduleAutoCalculation() }
    }
    
    @Published var isHiglobeEnabled: Bool {
        didSet { scheduleAutoCalculation() }
    }
    
    @Published private(set) var result: WorkHoursResult?
    @Published private(set) var isLoading = false
    @Published private(set) var hasCalculatedOnce = false
    
    // MARK: - Private State
    private let calculator = WorkHoursCalculator()
    private let monthYearOptionsInternal: [(label: String, date: Date)]
    
    private var calculationSequence = 0
    private var calculationDebounceTask: Task<Void, Never>?
    
    // MARK: - Init
    init(
        date: Date = Date(),
        hourlyRate: String = "15",
        nomadFeePct: String = "1.0",
        higlobeFeePct: String = "0.3",
        fxRateOverride: String = ""
    ) {
        self.hourlyRate = hourlyRate
        self.nomadFeePct = nomadFeePct
        self.higlobeFeePct = higlobeFeePct
        self.fxRateOverride = fxRateOverride
        self.isNomadEnabled = true
        self.isHiglobeEnabled = true
        
        let calendar = Calendar.current
        let options = Self.buildMonthYearOptions(calendar: calendar, around: date)
        self.monthYearOptionsInternal = options
        let defaultIndex = options.firstIndex {
            calendar.isDate($0.date, equalTo: date, toGranularity: .month)
        } ?? 0
        self.selectedMonthYearIndex = defaultIndex
    }
    
    deinit {
        calculationDebounceTask?.cancel()
    }
    
    // MARK: - Public Accessors
    var monthYearOptions: [(label: String, date: Date)] {
        monthYearOptionsInternal
    }
    
    var selectedMonthYearLabel: String {
        guard monthYearOptionsInternal.indices.contains(selectedMonthYearIndex) else {
            return "Período selecionado"
        }
        return monthYearOptionsInternal[selectedMonthYearIndex].label
    }
    
    var formattedHourlyRate: String? {
        guard let value = Double(hourlyRate) else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value))
    }
    
    // MARK: - User Intents
    func handleResultTabAppear() {
        guard !hasCalculatedOnce else { return }
        scheduleAutoCalculation(immediate: true)
    }
    
    // MARK: - Calculation Pipeline
    private func scheduleAutoCalculation(immediate: Bool = false) {
        calculationSequence += 1
        let requestID = calculationSequence
        calculationDebounceTask?.cancel()
        
        calculationDebounceTask = Task { [weak self] in
            guard let self = self else { return }
            if !immediate {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            guard !Task.isCancelled else { return }
            await self.generateInvoice(calculationID: requestID)
        }
    }
    
    private func generateInvoice(calculationID: Int) async {
        guard
            let hourlyRateValue = Double(hourlyRate),
            (!isNomadEnabled || Double(nomadFeePct) != nil),
            (!isHiglobeEnabled || Double(higlobeFeePct) != nil)
        else {
            if calculationID == calculationSequence {
                result = nil
                isLoading = false
            }
            return
        }
        
        let nomadFeePctValue = isNomadEnabled ? (Double(nomadFeePct) ?? 0) : 0
        let higlobeFeePctValue = isHiglobeEnabled ? (Double(higlobeFeePct) ?? 0) : 0
        let fxRateOverrideValue: Double? = fxRateOverride.isEmpty ? nil : Double(fxRateOverride)

        if calculationID == calculationSequence {
            isLoading = true
        }
        
        let options = WorkHoursOptions(
            month: selectedMonthDate,
            hourlyRate: hourlyRateValue,
            nomadFeePct: nomadFeePctValue,
            higlobeFeePct: higlobeFeePctValue,
            includeNomad: isNomadEnabled,
            includeHiglobe: isHiglobeEnabled,
            fxRate: fxRateOverrideValue,
            fxLabel: nil,
            mode: .both,
            includeXmasEve: true
        )

        let calculatedResult = await calculator.calculate(options: options)
        
        if calculationID == calculationSequence {
            result = calculatedResult
            isLoading = false
            hasCalculatedOnce = true
        }
    }
    
    // MARK: - Helpers
    private var selectedMonthDate: Date {
        guard monthYearOptionsInternal.indices.contains(selectedMonthYearIndex) else {
            return Date()
        }
        return monthYearOptionsInternal[selectedMonthYearIndex].date
    }
    
    private static func buildMonthYearOptions(
        calendar: Calendar,
        around date: Date
    ) -> [(label: String, date: Date)] {
        let currentYear = calendar.component(.year, from: date)
        let years = [currentYear - 1, currentYear, currentYear + 1]
        var options: [(String, Date)] = []
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        
        for year in years {
            for month in 1...12 {
                guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
                    continue
                }
                let monthName = formatter.monthSymbols[month - 1]
                options.append(("\(monthName) - \(year)", date))
            }
        }
        
        return options.sorted { $0.1 > $1.1 }.map { (label: $0.0, date: $0.1) }
    }
}
