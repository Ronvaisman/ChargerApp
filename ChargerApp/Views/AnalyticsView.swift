import SwiftUI
import Charts

struct AnalyticsView: View {
    @ObservedObject var viewModel: ChargingSessionViewModel
    @State private var selectedTimeframe: Timeframe = .month
    @State private var selectedMetric: AnalyticsMetric = .usage
    
    enum Timeframe: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    enum AnalyticsMetric: String, CaseIterable {
        case usage = "Usage"
        case cost = "Cost"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Date header
                    HStack {
                        Text("Apr 23")
                            .font(.title)
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(viewModel.totalKwhThisMonth(), specifier: "%.0f") kWh")
                            .font(.title2)
                    }
                    .padding(.horizontal)
                    
                    // Timeframe selector
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Usage Graph
                    VStack(alignment: .leading) {
                        Text("Electricity Usage (kWh)")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart {
                            ForEach(getChartData(), id: \.date) { data in
                                BarMark(
                                    x: .value("Date", data.date),
                                    y: .value("Usage", selectedMetric == .usage ? data.kwh : data.cost)
                                )
                                .foregroundStyle(Color.blue)
                            }
                        }
                        .frame(height: 200)
                        .padding()
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Cost Graph
                    VStack(alignment: .leading) {
                        Text("Cost (₪)")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart {
                            ForEach(getChartData(), id: \.date) { data in
                                LineMark(
                                    x: .value("Date", data.date),
                                    y: .value("Cost", data.cost)
                                )
                                .foregroundStyle(Color.green)
                            }
                        }
                        .frame(height: 200)
                        .padding()
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Summary Statistics
                    VStack(spacing: 15) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total This Month")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(viewModel.totalKwhThisMonth(), specifier: "%.1f") kWh")
                                    .font(.headline)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Total Cost")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("₪\(viewModel.totalCostThisMonth(), specifier: "%.2f")")
                                    .font(.headline)
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Unpaid Amount")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("₪\(viewModel.totalUnpaidAmount(), specifier: "%.2f")")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(Text(LocalizedStringKey("EV Charging Payment")))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func getChartData() -> [ChartData] {
        let calendar = Calendar.current
        let now = Date()
        var data: [ChartData] = []
        
        switch selectedTimeframe {
        case .week:
            // Last 7 days
            for dayOffset in (0...6).reversed() {
                if let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) {
                    let dayData = getDayData(for: date)
                    data.append(dayData)
                }
            }
        case .month:
            // Last 30 days
            for dayOffset in (0...29).reversed() {
                if let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) {
                    let dayData = getDayData(for: date)
                    data.append(dayData)
                }
            }
        case .year:
            // Last 12 months
            for monthOffset in (0...11).reversed() {
                if let date = calendar.date(byAdding: .month, value: -monthOffset, to: now) {
                    let monthData = getMonthData(for: date)
                    data.append(monthData)
                }
            }
        }
        
        return data
    }
    
    private func getDayData(for date: Date) -> ChartData {
        let calendar = Calendar.current
        let sessions = viewModel.sessions.filter { session in
            guard let sessionTimestamp = session.timestamp else { return false }
            return calendar.isDate(sessionTimestamp, inSameDayAs: date)
        }
        
        let kwh = sessions.reduce(0) { $0 + $1.kwhUsed }
        let cost = sessions.reduce(0) { $0 + $1.cost }
        
        return ChartData(date: date, kwh: kwh, cost: cost)
    }
    
    private func getMonthData(for date: Date) -> ChartData {
        let calendar = Calendar.current
        let sessions = viewModel.sessions.filter { session in
            guard let sessionTimestamp = session.timestamp else { return false }
            return calendar.isDate(sessionTimestamp, equalTo: date, toGranularity: .month)
        }
        
        let kwh = sessions.reduce(0) { $0 + $1.kwhUsed }
        let cost = sessions.reduce(0) { $0 + $1.cost }
        
        return ChartData(date: date, kwh: kwh, cost: cost)
    }
}

struct ChartData {
    let date: Date
    let kwh: Double
    let cost: Double
} 