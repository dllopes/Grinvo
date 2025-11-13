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

    func calculate(options: WorkHoursOptions) -> WorkHoursResult {
        // Later you'll port the real logic from work_hours.
        // For now we just build something fake to test the screen flow.

        let grossUsd = 160.0 * options.hourlyRate // e.g., 160h in the month
        let netUsd = grossUsd
        let fxRate = options.fxRate ?? 5.40
        let convertedBrl = netUsd * fxRate

        let withdraw = calculateWithdraw(
            conversionNet: convertedBrl,
            withdrawFeePct: options.withdrawFeePct,
            iofPct: options.iofPct,
            withdrawFeeBrl: options.withdrawFeeBrl
        )

        let summary = """
        [INVOICE PREVIEW]

        Month: \(formattedMonth(options.month))

        Gross (USD): \(grossUsd)
        Net (USD): \(netUsd)
        Converted (BRL): \(convertedBrl)

        Withdraw fees (BRL): \(withdraw.fees)
        Withdraw net (BRL): \(withdraw.net)
        """

        return WorkHoursResult(
            summaryText: summary,
            grossUsd: grossUsd,
            netUsd: netUsd,
            convertedBrl: convertedBrl,
            withdrawFeesBrl: withdraw.fees,
            withdrawNetBrl: withdraw.net
        )
    }

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

    private func formattedMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
