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
    var mode: Mode

    enum Mode {
        case conversion
        case withdraw
        case both
    }
}

struct WorkHoursResult {
    var summaryText: String
    var grossUsd: Double
    var netUsd: Double
    var convertedBrl: Double
    var withdrawFeesBrl: Double?
    var withdrawNetBrl: Double?
}
