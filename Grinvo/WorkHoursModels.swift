//
//  WorkHoursModels.swift
//  Grinvo
//
//  Created by Diego Lopes on 13/11/25.
//

import Foundation

struct WorkHoursOptions {
    var month: Date
    var hourlyRate: Double
    var spreadPct: Double
    var withdrawFeePct: Double
    var withdrawFeeBrl: Double
    var iofPct: Double
    var fxRate: Double?
    var fxLabel: String?
    var mode: Mode
    var includeXmasEve: Bool

    enum Mode {
        case conversion
        case withdraw
        case both
    }
    
    init(
        month: Date,
        hourlyRate: Double,
        spreadPct: Double,
        withdrawFeePct: Double,
        withdrawFeeBrl: Double,
        iofPct: Double,
        fxRate: Double? = nil,
        fxLabel: String? = nil,
        mode: Mode = .both,
        includeXmasEve: Bool = true
    ) {
        self.month = month
        self.hourlyRate = hourlyRate
        self.spreadPct = spreadPct
        self.withdrawFeePct = withdrawFeePct
        self.withdrawFeeBrl = withdrawFeeBrl
        self.iofPct = iofPct
        self.fxRate = fxRate
        self.fxLabel = fxLabel
        self.mode = mode
        self.includeXmasEve = includeXmasEve
    }
}

struct WorkHoursResult: Equatable {
    var summaryText: String
    var grossUsd: Double
    var netUsd: Double
    var convertedBrl: Double
    var withdrawFeesBrl: Double?
    var withdrawNetBrl: Double?
    
    // Detailed breakdown
    var workDays: Int
    var workHours: Int
    var paidHolidays: Int
    var holidayHours: Int
    var totalHours: Int
    var paidHolidayDates: [Date]
    var fxRate: Double?
    var fxSource: String?
    var fxAsOf: String?
    var conversionGrossBrl: Double
    var spreadFeeBrl: Double
    var conversionNetBrl: Double
}
