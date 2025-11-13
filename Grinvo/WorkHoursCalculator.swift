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
            formatter.locale = Locale.current
            formatter.dateFormat = "dd/MM/yyyy HH:mm"
            formatter.timeZone = TimeZone.current
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
        var nomadFeesBrl: Double? = nil
        var nomadNetBrl: Double? = nil
        var higlobeFeesBrl: Double? = nil
        var higlobeNetBrl: Double? = nil
        
        if let fx = fxRate {
            conversionGrossBrl = amountUsd * fx.rate
            
            if options.mode == .withdraw || options.mode == .both {
                let nomad = calculatePayout(conversionAmount: conversionGrossBrl, feePct: options.nomadFeePct)
                nomadFeesBrl = nomad.fees
                nomadNetBrl = nomad.net
                
                let higlobe = calculatePayout(conversionAmount: conversionGrossBrl, feePct: options.higlobeFeePct)
                higlobeFeesBrl = higlobe.fees
                higlobeNetBrl = higlobe.net
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
            nomadFeePct: options.nomadFeePct,
            nomadFeesBrl: nomadFeesBrl,
            nomadNetBrl: nomadNetBrl,
            higlobeFeePct: options.higlobeFeePct,
            higlobeFeesBrl: higlobeFeesBrl,
            higlobeNetBrl: higlobeNetBrl,
            paidHolidayDates: paidHolidays,
            mode: options.mode
        )
        
        return WorkHoursResult(
            summaryText: summary,
            grossUsd: amountUsd,
            netUsd: amountUsd,
            convertedBrl: conversionGrossBrl,
            nomadFeePct: options.nomadFeePct,
            nomadFeesBrl: nomadFeesBrl,
            nomadNetBrl: nomadNetBrl,
            higlobeFeePct: options.higlobeFeePct,
            higlobeFeesBrl: higlobeFeesBrl,
            higlobeNetBrl: higlobeNetBrl,
            workDays: workDays.count,
            workHours: workHours,
            paidHolidays: paidHolidays.count,
            holidayHours: holidayHours,
            totalHours: totalHours,
            paidHolidayDates: paidHolidays,
            fxRate: fxRate?.rate,
            fxSource: fxRate?.source,
            fxAsOf: fxRate?.asOf,
            conversionGrossBrl: conversionGrossBrl
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
        nomadFeePct: Double,
        nomadFeesBrl: Double?,
        nomadNetBrl: Double?,
        higlobeFeePct: Double,
        higlobeFeesBrl: Double?,
        higlobeNetBrl: Double?,
        paidHolidayDates: [Date],
        mode: WorkHoursOptions.Mode
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
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
            summary += "  Conversão (BRL): R$ \(String(format: "%.2f", conversionGrossBrl))\n"
            
            if mode == .withdraw || mode == .both {
                summary += "  --- Nomad / Husky ---\n"
                summary += "    Taxa: \(String(format: "%.2f", nomadFeePct))%\n"
                if let fees = nomadFeesBrl {
                    summary += "    Tarifas: R$ \(String(format: "%.2f", fees))\n"
                }
                if let net = nomadNetBrl {
                    summary += "    Líquido: R$ \(String(format: "%.2f", net))\n"
                }
                
                summary += "  --- HiGlobe ---\n"
                summary += "    Taxa: \(String(format: "%.2f", higlobeFeePct))%\n"
                if let fees = higlobeFeesBrl {
                    summary += "    Tarifas: R$ \(String(format: "%.2f", fees))\n"
                }
                if let net = higlobeNetBrl {
                    summary += "    Líquido: R$ \(String(format: "%.2f", net))\n"
                }
            }
        } else {
            summary += "  FX Rate:         unavailable (offline or API error)\n"
        }
        
        if !paidHolidayDates.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale.current
            // Use template to get locale-appropriate format
            let template = "ddMMyyyyEEE"
            if let dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: Locale.current) {
                dateFormatter.dateFormat = dateFormat
            } else {
                dateFormatter.dateFormat = "dd/MM/yyyy (EEE)"
            }
            let holidayList = paidHolidayDates.map { dateFormatter.string(from: $0) }.joined(separator: ", ")
            summary += "  Holidays in month: \(holidayList)\n"
        }
        
        return summary
    }
    
    // MARK: - Helper Methods
    
    private func calculatePayout(
        conversionAmount: Double,
        feePct: Double
    ) -> (fees: Double, net: Double) {
        let fees = conversionAmount * (feePct / 100.0)
        let net = conversionAmount - fees
        return (fees: fees, net: net)
    }
    
    private func createErrorResult(message: String) -> WorkHoursResult {
        return WorkHoursResult(
            summaryText: "Error: \(message)",
            grossUsd: 0,
            netUsd: 0,
            convertedBrl: 0,
            nomadFeePct: 0,
            nomadFeesBrl: nil,
            nomadNetBrl: nil,
            higlobeFeePct: 0,
            higlobeFeesBrl: nil,
            higlobeNetBrl: nil,
            workDays: 0,
            workHours: 0,
            paidHolidays: 0,
            holidayHours: 0,
            totalHours: 0,
            paidHolidayDates: [],
            fxRate: nil,
            fxSource: nil,
            fxAsOf: nil,
            conversionGrossBrl: 0
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
