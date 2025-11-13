//
//  ContentView.swift
//  Grinvo
//
//  Created by Diego Lopes on 13/11/25.
//

import SwiftUI

import SwiftUI

struct ContentView: View {
    @State private var spreadPct = "1.0"
    @State private var withdrawFeePct = "0.0"
    @State private var withdrawFeeBrl = "0.0"
    @State private var iofPct = "0.0"

    var body: some View {
        Form {
            Section(header: Text("Rates")) {
                TextField("Spread (%)", text: $spreadPct)
                    .applyDecimalKeyboard()
            }

            Section(header: Text("Withdraw fees")) {
                TextField("Withdraw fee (%)", text: $withdrawFeePct)
                    .applyDecimalKeyboard()

                TextField("Withdraw fixed fee (BRL)", text: $withdrawFeeBrl)
                    .applyDecimalKeyboard()

                TextField("IOF / extra (%)", text: $iofPct)
                    .applyDecimalKeyboard()
            }
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
}

#Preview {
    ContentView()
}
