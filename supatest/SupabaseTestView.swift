//
//  SupabaseTestView.swift
//  supatest
//
//  Created by Claude on 12/5/25.
//

import SwiftUI
import Supabase

// 在 View 外部定义 SupabaseClient 实例
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://eyprepalhwevgoryqyqf.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV5cHJlcGFsaHdldmdvcnlxeXFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MTA4NzQsImV4cCI6MjA4MDQ4Njg3NH0.jQTsSghESebOsiT9DdPK6gQ9Tn3zAvJ3mTrTs_oxtuc"
)

struct SupabaseTestView: View {
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var logText: String = "点击按钮开始测试连接..."
    @State private var isTesting: Bool = false

    enum ConnectionStatus {
        case idle
        case success
        case failure
    }

    var body: some View {
        VStack(spacing: 20) {
            // 状态图标
            statusIcon
                .font(.system(size: 60))
                .padding(.top, 40)

            // 状态文字
            Text(statusTitle)
                .font(.headline)
                .foregroundColor(statusColor)

            // 调试日志文本框
            ScrollView {
                Text(logText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)

            Spacer()

            // 测试连接按钮
            Button(action: {
                testConnection()
            }) {
                HStack {
                    if isTesting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.trailing, 5)
                    }
                    Text(isTesting ? "测试中..." : "测试连接")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isTesting ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isTesting)
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .navigationTitle("Supabase 连接测试")
    }

    // MARK: - 状态相关计算属性

    private var statusIcon: some View {
        Group {
            switch connectionStatus {
            case .idle:
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.gray)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failure:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }

    private var statusTitle: String {
        switch connectionStatus {
        case .idle:
            return "等待测试"
        case .success:
            return "连接成功"
        case .failure:
            return "连接失败"
        }
    }

    private var statusColor: Color {
        switch connectionStatus {
        case .idle:
            return .gray
        case .success:
            return .green
        case .failure:
            return .red
        }
    }

    // MARK: - 测试连接逻辑

    private func testConnection() {
        Task {
            await MainActor.run {
                isTesting = true
                connectionStatus = .idle
                logText = "开始测试连接...\n"
                logText += "URL: https://eyprepalhwevgoryqyqf.supabase.co\n"
                logText += "正在查询不存在的表以验证连接...\n\n"
            }

            do {
                // 故意查询一个不存在的表
                _ = try await supabase.from("non_existent_table").select().execute()

                // 如果没有抛出错误（不太可能），说明表存在
                await MainActor.run {
                    connectionStatus = .success
                    logText += "✅ 连接成功（查询执行完成）\n"
                    isTesting = false
                }
            } catch {
                let errorString = String(describing: error)

                await MainActor.run {
                    logText += "捕获到错误:\n\(errorString)\n\n"

                    // 判断错误类型
                    if errorString.contains("relation") && errorString.contains("does not exist") {
                        // 数据库响应了"表不存在"的错误，说明连接成功
                        connectionStatus = .success
                        logText += "✅ 连接成功（服务器已响应）\n"
                        logText += "说明：数据库正确返回了'表不存在'的错误，证明连接正常。"
                    } else if errorString.contains("PGRST") || errorString.contains("Could not find the table") {
                        // PostgREST 返回的错误（如 PGRST205），说明连接成功
                        connectionStatus = .success
                        logText += "✅ 连接成功（服务器已响应）\n"
                        logText += "说明：Supabase 服务器正确返回了'表不存在'的错误，证明连接正常。"
                    } else if errorString.lowercased().contains("hostname") ||
                              errorString.lowercased().contains("url") ||
                              errorString.contains("NSURLErrorDomain") ||
                              errorString.contains("Could not connect") {
                        // URL 错误或网络问题
                        connectionStatus = .failure
                        logText += "❌ 连接失败：URL 错误或无网络\n"
                        logText += "请检查网络连接和 Supabase URL 配置。"
                    } else {
                        // 其他错误
                        connectionStatus = .failure
                        logText += "❌ 发生其他错误\n"
                        logText += "错误详情: \(error.localizedDescription)"
                    }

                    isTesting = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
