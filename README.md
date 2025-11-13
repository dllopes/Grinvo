# Grinvo

Simple multiplatform app (iOS + macOS) to calculate my monthly work invoice.

## What it does

- Select invoice month
- Input:
  - Hourly rate (USD/hour)
  - Spread percentage
  - Withdraw fees (percentage and fixed BRL)
  - IOF or extra percentage
- Calculates:
  - Net amount in USD
  - Converted amount in BRL
  - Final value after withdraw fees
- Shows a text summary ready to copy into the invoice I send to the company.

## Tech

- Swift
- SwiftUI
- Multiplatform target (iOS + macOS)

## Roadmap

- [ ] Port all logic from `work_hours` script
- [ ] Add presets for common months and holidays
- [ ] Export invoice as PDF
- [ ] Share via system share sheet