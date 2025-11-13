//
//  WorkHoursCalculator.swift
//  Grinvo
//
//  Created by Diego Lopes on 13/11/25.
//  by Diego Lopes
//
//  Subtitle: Calculates hours and conversions to generate a monthly invoice (USD → BRL),
//  including withdrawal fees and IOF simulation.
//

import Foundation

struct WorkHoursCalculator {
    private let fxService = FXRateService()
    private let calendar = Calendar.current
    
    // MARK: - Main Calculation
    
    func calculate(options: WorkHoursOptions) async -> WorkHoursResult {
        // Extract year and month from the date
        let components = calendar.dateComponents([.year, .month], from: options.month)
        guard let year = components.year, let month = components.month else {
            return createErrorResult(message: "Invalid date")
        }
        
        // Get month range
        guard let monthStartRaw = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let monthEndRaw = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStartRaw) else {
            return createErrorResult(message: "Invalid month range")
        }
        
        let monthStart = normalizeDate(monthStartRaw)
        let monthEnd = normalizeDate(monthEndRaw)
        
        // Calculate holidays for current year, previous year, and next year
        var allHolidays = Set<Date>()
        allHolidays.formUnion(usFederalHolidays(year: year - 1, includeXmasEve: options.includeXmasEve))
        allHolidays.formUnion(usFederalHolidays(year: year, includeXmasEve: options.includeXmasEve))
        allHolidays.formUnion(usFederalHolidays(year: year + 1, includeXmasEve: options.includeXmasEve))
        
        // Calculate workdays and paid holidays
        let (workDays, paidHolidays) = calculateWorkdays(
            monthStart: monthStart,
            monthEnd: monthEnd,
            holidays: allHolidays
        )
        
        // Calculate hours
        let workHours = workDays.count * 8
        let holidayHours = paidHolidays.count * 8
        let totalHours = workHours + holidayHours
        
        // Calculate USD amount
        let amountUsd = Double(totalHours) * options.hourlyRate
        
        // Fetch FX rate or use override
        let fxRate: FXRate?
        if let overrideRate = options.fxRate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm zzz"
            fxRate = FXRate(
                rate: overrideRate,
                source: options.fxLabel ?? "Manual override",
                asOf: formatter.string(from: Date())
            )
        } else {
            fxRate = try? await fxService.fetchRate()
        }
        
        // Calculate BRL conversion
        var conversionGrossBrl: Double = 0
        var spreadFeeBrl: Double = 0
        var conversionNetBrl: Double = 0
        var withdrawFeesBrl: Double? = nil
        var withdrawNetBrl: Double? = nil
        
        if let fx = fxRate {
            conversionGrossBrl = amountUsd * fx.rate
            spreadFeeBrl = conversionGrossBrl * (options.spreadPct / 100.0)
            conversionNetBrl = conversionGrossBrl - spreadFeeBrl
            
            // Calculate withdraw fees if applicable
            let extraFeesPresent = options.withdrawFeePct > 0.0 || 
                                   options.iofPct > 0.0 || 
                                   options.withdrawFeeBrl > 0.0
            
            if extraFeesPresent && (options.mode == .withdraw || options.mode == .both) {
                let pctTotal = (options.withdrawFeePct + options.iofPct) / 100.0
                withdrawFeesBrl = (conversionNetBrl * pctTotal) + options.withdrawFeeBrl
                withdrawNetBrl = conversionNetBrl - (withdrawFeesBrl ?? 0)
            }
        }
        
        // Generate summary text
        let summary = generateSummary(
            month: options.month,
            workDays: workDays.count,
            workHours: workHours,
            paidHolidays: paidHolidays.count,
            holidayHours: holidayHours,
            totalHours: totalHours,
            hourlyRate: options.hourlyRate,
            amountUsd: amountUsd,
            fxRate: fxRate,
            conversionGrossBrl: conversionGrossBrl,
            spreadPct: options.spreadPct,
            spreadFeeBrl: spreadFeeBrl,
            conversionNetBrl: conversionNetBrl,
            withdrawFeePct: options.withdrawFeePct,
            iofPct: options.iofPct,
            withdrawFeeBrl: options.withdrawFeeBrl,
            withdrawFeesBrl: withdrawFeesBrl,
            withdrawNetBrl: withdrawNetBrl,
            paidHolidayDates: paidHolidays,
            mode: options.mode
        )
        
        return WorkHoursResult(
            summaryText: summary,
            grossUsd: amountUsd,
            netUsd: amountUsd,
            convertedBrl: conversionNetBrl,
            withdrawFeesBrl: withdrawFeesBrl,
            withdrawNetBrl: withdrawNetBrl,
            workDays: workDays.count,
            workHours: workHours,
            paidHolidays: paidHolidays.count,
            holidayHours: holidayHours,
            totalHours: totalHours,
            paidHolidayDates: paidHolidays,
            fxRate: fxRate?.rate,
            fxSource: fxRate?.source,
            fxAsOf: fxRate?.asOf,
            conversionGrossBrl: conversionGrossBrl,
            spreadFeeBrl: spreadFeeBrl,
            conversionNetBrl: conversionNetBrl
        )
    }
    
    // MARK: - US Federal Holidays
    
    func usFederalHolidays(year: Int, includeXmasEve: Bool) -> Set<Date> {
        var holidays = Set<Date>()
        
        // New Year's Day
        holidays.insert(normalizeDate(observed(date: Date.newYear(year: year))))
        
        // Memorial Day (last Monday of May)
        holidays.insert(normalizeDate(lastMonday(year: year, month: 5)))
        
        // Independence Day (July 4)
        holidays.insert(normalizeDate(observed(date: Date.independenceDay(year: year))))
        
        // Labor Day (first Monday of September)
        holidays.insert(normalizeDate(firstMonday(year: year, month: 9)))
        
        // Thanksgiving (fourth Thursday of November)
        let thanksgiving = normalizeDate(fourthThursday(year: year, month: 11))
        holidays.insert(thanksgiving)
        
        // Black Friday (day after Thanksgiving)
        if let blackFriday = calendar.date(byAdding: .day, value: 1, to: thanksgiving) {
            holidays.insert(normalizeDate(blackFriday))
        }
        
        // Christmas Day
        holidays.insert(normalizeDate(observed(date: Date.christmas(year: year))))
        
        // Christmas Eve (optional)
        if includeXmasEve {
            holidays.insert(normalizeDate(Date.christmasEve(year: year)))
        }
        
        return holidays
    }
    
    private func observed(date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        // weekday: 1 = Sunday, 7 = Saturday
        if weekday == 1 { // Sunday -> Monday
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        } else if weekday == 7 { // Saturday -> Friday
            return calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return date
    }
    
    private func lastMonday(year: Int, month: Int) -> Date {
        guard let lastDayOfMonth = calendar.date(from: DateComponents(year: year, month: month + 1, day: 0)) else {
            return Date()
        }
        
        let weekday = calendar.component(.weekday, from: lastDayOfMonth)
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        // Convert to 0=Sunday, 1=Monday, ..., 6=Saturday for calculation
        let wday = (weekday == 1) ? 0 : weekday - 1
        let daysToSubtract = (wday - 1) % 7
        if daysToSubtract < 0 {
            return calendar.date(byAdding: .day, value: -(daysToSubtract + 7), to: lastDayOfMonth) ?? lastDayOfMonth
        }
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: lastDayOfMonth) ?? lastDayOfMonth
    }
    
    private func firstMonday(year: Int, month: Int) -> Date {
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return Date()
        }
        
        let weekday = calendar.component(.weekday, from: firstDay)
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        // Convert to 0=Sunday, 1=Monday, ..., 6=Saturday for calculation
        let wday = (weekday == 1) ? 0 : weekday - 1
        let daysToAdd = (1 - wday) % 7
        if daysToAdd < 0 {
            return calendar.date(byAdding: .day, value: daysToAdd + 7, to: firstDay) ?? firstDay
        }
        return calendar.date(byAdding: .day, value: daysToAdd, to: firstDay) ?? firstDay
    }
    
    private func fourthThursday(year: Int, month: Int) -> Date {
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return Date()
        }
        
        let weekday = calendar.component(.weekday, from: firstDay)
        // weekday: 1 = Sunday, 2 = Monday, ..., 5 = Thursday, ..., 7 = Saturday
        // Convert to 0=Sunday, 1=Monday, ..., 4=Thursday, ..., 6=Saturday
        let wday = (weekday == 1) ? 0 : weekday - 1
        // Find first Thursday (wday 4)
        let daysToFirstThursday = (4 - wday) % 7
        let adjustedDays = daysToFirstThursday < 0 ? daysToFirstThursday + 7 : daysToFirstThursday
        guard let firstThursday = calendar.date(byAdding: .day, value: adjustedDays, to: firstDay) else {
            return Date()
        }
        
        // Add 21 days to get fourth Thursday
        return calendar.date(byAdding: .day, value: 21, to: firstThursday) ?? firstThursday
    }
    
    // MARK: - Workdays Calculation
    
    private func normalizeDate(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components) ?? date
    }
    
    func calculateWorkdays(monthStart: Date, monthEnd: Date, holidays: Set<Date>) -> (workDays: [Date], paidHolidays: [Date]) {
        var workDays: [Date] = []
        var paidHolidays: [Date] = []
        
        // Normalize holidays set for comparison
        let normalizedHolidays = Set(holidays.map { normalizeDate($0) })
        
        var currentDate = monthStart
        while currentDate <= monthEnd {
            let normalizedCurrent = normalizeDate(currentDate)
            let weekday = calendar.component(.weekday, from: normalizedCurrent)
            // weekday: 1 = Sunday, 7 = Saturday
            // Only include Monday (2) through Friday (6)
            if weekday >= 2 && weekday <= 6 {
                if normalizedHolidays.contains(normalizedCurrent) {
                    paidHolidays.append(normalizedCurrent)
                } else {
                    workDays.append(normalizedCurrent)
                }
            }
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        
        return (workDays: workDays, paidHolidays: paidHolidays)
    }
    
    // MARK: - Summary Generation
    
    private func generateSummary(
        month: Date,
        workDays: Int,
        workHours: Int,
        paidHolidays: Int,
        holidayHours: Int,
        totalHours: Int,
        hourlyRate: Double,
        amountUsd: Double,
        fxRate: FXRate?,
        conversionGrossBrl: Double,
        spreadPct: Double,
        spreadFeeBrl: Double,
        conversionNetBrl: Double,
        withdrawFeePct: Double,
        iofPct: Double,
        withdrawFeeBrl: Double,
        withdrawFeesBrl: Double?,
        withdrawNetBrl: Double?,
        paidHolidayDates: [Date],
        mode: WorkHoursOptions.Mode
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let monthStr = formatter.string(from: month)
        
        var summary = "\(monthStr)\n"
        summary += "  Work Days:       \(workDays) (\(workHours)h)\n"
        summary += "  Paid Holidays:   \(paidHolidays) (\(holidayHours)h)\n"
        summary += "  Total Hours:     \(totalHours)h\n"
        summary += "  Hourly Rate:     $\(String(format: "%.2f", hourlyRate)) USD/h\n"
        summary += "  Amount (USD):    $\(String(format: "%.2f", amountUsd))\n"
        
        if let fx = fxRate {
            summary += "  FX Base Rate:    \(String(format: "%.4f", fx.rate)) BRL/USD (\(fx.source), as of \(fx.asOf))\n"
            summary += "  Spread (post-conv deduction): \(String(format: "%.2f", spreadPct))%\n"
            summary += "  Conversion (BRL, gross):      R$ \(String(format: "%.2f", conversionGrossBrl))\n"
            summary += "  Spread fee (BRL):             R$ \(String(format: "%.2f", spreadFeeBrl))\n"
            summary += "  Conversion (BRL, net after spread): R$ \(String(format: "%.2f", conversionNetBrl))\n"
            
            let extraFeesPresent = withdrawFeePct > 0.0 || iofPct > 0.0 || withdrawFeeBrl > 0.0
            if extraFeesPresent && (mode == .withdraw || mode == .both) {
                summary += "  --- Withdraw (extra fees over BRL after spread) ---\n"
                summary += "    Fees %:              \(String(format: "%.2f", withdrawFeePct))%\n"
                summary += "    Extra % (IOF/taxes): \(String(format: "%.2f", iofPct))%\n"
                summary += "    Fixed fee (BRL):     R$ \(String(format: "%.2f", withdrawFeeBrl))\n"
                if let fees = withdrawFeesBrl {
                    summary += "    Total fees (BRL):    R$ \(String(format: "%.2f", fees))\n"
                }
                if let net = withdrawNetBrl {
                    summary += "    Net after withdraw:  R$ \(String(format: "%.2f", net))\n"
                }
            }
        } else {
            summary += "  FX Rate:         unavailable (offline or API error)\n"
        }
        
        if !paidHolidayDates.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd (EEE)"
            let holidayList = paidHolidayDates.map { dateFormatter.string(from: $0) }.joined(separator: ", ")
            summary += "  Holidays in month: \(holidayList)\n"
        }
        
        return summary
    }
    
    // MARK: - Helper Methods
    
    func calculateWithdraw(
        conversionNet: Double,
        withdrawFeePct: Double,
        iofPct: Double,
        withdrawFeeBrl: Double
    ) -> (fees: Double, net: Double) {
        let pctTotal = (withdrawFeePct + iofPct) / 100.0
        let withdrawFees = (conversionNet * pctTotal) + withdrawFeeBrl
        let withdrawNet = conversionNet - withdrawFees
        return (fees: withdrawFees, net: withdrawNet)
    }
    
    private func createErrorResult(message: String) -> WorkHoursResult {
        return WorkHoursResult(
            summaryText: "Error: \(message)",
            grossUsd: 0,
            netUsd: 0,
            convertedBrl: 0,
            withdrawFeesBrl: nil,
            withdrawNetBrl: nil,
            workDays: 0,
            workHours: 0,
            paidHolidays: 0,
            holidayHours: 0,
            totalHours: 0,
            paidHolidayDates: [],
            fxRate: nil,
            fxSource: nil,
            fxAsOf: nil,
            conversionGrossBrl: 0,
            spreadFeeBrl: 0,
            conversionNetBrl: 0
        )
    }
}

// MARK: - Date Extensions

private extension Date {
    static func newYear(year: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
    }
    
    static func independenceDay(year: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: DateComponents(year: year, month: 7, day: 4)) ?? Date()
    }
    
    static func christmas(year: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: DateComponents(year: year, month: 12, day: 25)) ?? Date()
    }
    
    static func christmasEve(year: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: DateComponents(year: year, month: 12, day: 24)) ?? Date()
    }
}
