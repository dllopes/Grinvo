//
//  FXRateService.swift
//  Grinvo
//
//  Created by Diego Lopes on 13/11/25.
//

import Foundation

struct FXRate {
    let rate: Double
    let source: String
    let asOf: String
}

enum FXRateError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case noData
    case parsingError
}

class FXRateService {
    private let session: URLSession
    private let timeout: TimeInterval = 10.0
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Fetches USD→BRL rate from BCB/PTAX API, trying the last 7 days
    func fetchBCBPtax(date: Date = Date()) async throws -> FXRate? {
        let calendar = Calendar.current
        
        for i in 0...7 {
            guard let targetDate = calendar.date(byAdding: .day, value: -i, to: date) else {
                continue
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM-dd-yyyy"
            let dateStr = dateFormatter.string(from: targetDate)
            
            let urlString = "https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/" +
                "CotacaoDolarPeriodoFechamento(dataInicial='\(dateStr)',dataFinalCotacao='\(dateStr)')?" +
                "$top=1&$orderby=dataHoraCotacao%20desc&$format=json"
            
            guard let url = URL(string: urlString) else {
                continue
            }
            
            do {
                let (data, response) = try await session.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continue
                }
                
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let value = json["value"] as? [[String: Any]],
                      let first = value.first else {
                    continue
                }
                
                // Try cotacaoVenda first, fallback to cotacaoCompra
                let rate: Double?
                if let venda = first["cotacaoVenda"] as? Double {
                    rate = venda
                } else if let compra = first["cotacaoCompra"] as? Double {
                    rate = compra
                } else {
                    continue
                }
                
                guard let finalRate = rate else {
                    continue
                }
                
                let dataHora = first["dataHoraCotacao"] as? String ?? targetDate.description
                
                return FXRate(
                    rate: finalRate,
                    source: "BCB/PTAX",
                    asOf: dataHora
                )
            } catch {
                // Continue to next day if this one fails
                continue
            }
        }
        
        return nil
    }
    
    /// Fetches USD→BRL rate from AwesomeAPI
    func fetchAwesomeAPI() async throws -> FXRate? {
        guard let url = URL(string: "https://economia.awesomeapi.com.br/json/last/USD-BRL") else {
            throw FXRateError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw FXRateError.invalidResponse
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pair = json["USDBRL"] as? [String: Any],
                  let askStr = pair["ask"] as? String,
                  let ask = Double(askStr),
                  let timestampStr = pair["timestamp"] as? String,
                  let timestamp = Double(timestampStr) else {
                throw FXRateError.parsingError
            }
            
            let date = Date(timeIntervalSince1970: timestamp)
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.dateFormat = "dd/MM/yyyy HH:mm"
            formatter.timeZone = TimeZone.current
            let asOf = formatter.string(from: date)
            
            return FXRate(
                rate: ask,
                source: "AwesomeAPI",
                asOf: asOf
            )
        } catch {
            throw FXRateError.networkError(error)
        }
    }
    
    /// Fetches USD→BRL rate, trying BCB first, then AwesomeAPI as fallback
    func fetchRate(date: Date = Date()) async throws -> FXRate {
        // Try BCB first
        if let bcbRate = try await fetchBCBPtax(date: date) {
            return bcbRate
        }
        
        // Fallback to AwesomeAPI
        if let awesomeRate = try await fetchAwesomeAPI() {
            return awesomeRate
        }
        
        throw FXRateError.noData
    }
}
