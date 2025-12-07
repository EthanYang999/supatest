//
//  AuthManager.swift
//  supatest
//
//  EarthLord 游戏认证管理器
//  负责处理用户注册、登录、找回密码等认证流程
//

import Foundation
import Combine
import Supabase
import GoogleSignIn

// MARK: - 认证模式枚举

/// 认证模式
enum AuthMode: String, CaseIterable {
    case login = "登录"
    case register = "注册"
    case resetPassword = "找回密码"
}

// MARK: - 响应模型

/// 删除账户错误响应
private struct DeleteAccountErrorResponse: Codable {
    let error: String
    let details: String?
}

// MARK: - AuthManager

/// 认证管理器
/// 负责处理所有与用户认证相关的操作
@MainActor
class AuthManager: ObservableObject {

    // MARK: - 单例

    static let shared = AuthManager()

    // MARK: - 发布属性

    /// 用户是否已认证
    @Published var isAuthenticated: Bool = false

    /// 当前登录的用户
    @Published var currentUser: User?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 验证码是否已发送
    @Published var otpSent: Bool = false

    /// 当前认证模式
    @Published var authMode: AuthMode = .login

    /// 是否已完成初始化检查
    @Published var isInitialized: Bool = false

    /// 验证码是否已验证
    @Published var otpVerified: Bool = false

    /// 是否需要设置密码（注册或找回密码流程中使用）
    @Published var needsPasswordSetup: Bool = false

    // MARK: - 私有属性

    /// 临时存储邮箱，用于验证流程
    private var pendingEmail: String?

    /// 认证状态监听任务
    private var authStateTask: Task<Void, Never>?

    // MARK: - 初始化

    private init() {
        // 启动认证状态监听
        startAuthStateListener()
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - 认证状态监听

    /// 开始监听认证状态变化
    private func startAuthStateListener() {
        authStateTask = Task { [weak self] in
            guard let self = self else { return }

            // 监听 Supabase 认证状态变化
            for await (event, session) in supabase.auth.authStateChanges {
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    switch event {
                    case .initialSession:
                        // 初始会话检查完成
                        if let session = session {
                            self.currentUser = session.user
                            self.isAuthenticated = true
                            print("✅ 初始会话有效，用户ID: \(session.user.id)")
                        } else {
                            self.currentUser = nil
                            self.isAuthenticated = false
                            print("ℹ️ 无初始会话")
                        }
                        self.isInitialized = true

                    case .signedIn:
                        // 用户登录
                        if let session = session {
                            self.currentUser = session.user
                            // 如果正在设置密码流程中，不要设置 isAuthenticated
                            if !self.needsPasswordSetup {
                                self.isAuthenticated = true
                                print("✅ 用户已登录: \(session.user.id)")
                            } else {
                                print("ℹ️ 用户已验证，等待设置密码: \(session.user.id)")
                            }
                        }

                    case .signedOut:
                        // 用户登出
                        self.currentUser = nil
                        self.isAuthenticated = false
                        self.otpSent = false
                        self.otpVerified = false
                        self.needsPasswordSetup = false
                        self.pendingEmail = nil
                        print("ℹ️ 用户已登出")

                    case .tokenRefreshed:
                        // Token 刷新
                        if let session = session {
                            self.currentUser = session.user
                            print("🔄 Token 已刷新")
                        }

                    case .userUpdated:
                        // 用户信息更新
                        if let session = session {
                            self.currentUser = session.user
                            print("🔄 用户信息已更新")
                        }

                    case .passwordRecovery:
                        // 密码恢复
                        print("🔐 密码恢复流程")

                    case .mfaChallengeVerified:
                        // MFA 验证
                        print("🔐 MFA 验证完成")

                    case .userDeleted:
                        // 用户删除
                        self.currentUser = nil
                        self.isAuthenticated = false
                        print("⚠️ 用户已删除")
                    }
                }
            }
        }
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送OTP验证码，shouldCreateUser: true 表示如果用户不存在则创建
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            pendingEmail = email
            otpSent = true
            print("✅ 注册验证码已发送至: \(email)")

        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证注册验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil
        // 标记需要设置密码，防止 signedIn 事件触发 isAuthenticated
        needsPasswordSetup = true

        do {
            // 验证OTP
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            currentUser = session.user
            otpVerified = true
            // 不设置 isAuthenticated = true，等待用户设置密码
            print("✅ 注册验证码验证成功，用户ID: \(session.user.id)")

        } catch {
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            needsPasswordSetup = false
            print("❌ 验证注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 设置密码（注册流程最后一步，已废弃，请使用 completeRegistration）
    /// - Parameter password: 用户设置的密码
    @available(*, deprecated, message: "请使用 completeRegistration(password:) 方法")
    func setPassword(password: String) async {
        await completeRegistration(password: password)
    }

    /// 完成注册（设置密码并完成认证）
    /// - Parameter password: 用户设置的密码
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: UserAttributes(password: password))

            // 重置状态并标记为已认证
            needsPasswordSetup = false
            otpVerified = false
            isAuthenticated = true
            print("✅ 注册完成，密码设置成功")

        } catch {
            errorMessage = "设置密码失败: \(error.localizedDescription)"
            print("❌ 设置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 登录方法

    /// 邮箱密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            currentUser = session.user
            isAuthenticated = true
            print("✅ 登录成功，用户ID: \(session.user.id)")

        } catch {
            errorMessage = "登录失败: \(error.localizedDescription)"
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送找回密码验证码
    /// - Parameter email: 用户邮箱
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 使用 resetPasswordForEmail 发送重置密码验证码
            try await supabase.auth.resetPasswordForEmail(email)

            pendingEmail = email
            otpSent = true
            print("✅ 重置密码验证码已发送至: \(email)")

        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证找回密码验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil
        // 标记需要设置密码，防止 signedIn 事件触发 isAuthenticated
        needsPasswordSetup = true

        do {
            // 验证OTP，使用 .recovery 类型
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            currentUser = session.user
            otpVerified = true
            // 不设置 isAuthenticated = true，等待用户重置密码
            print("✅ 重置验证码验证成功，可以设置新密码")

        } catch {
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            needsPasswordSetup = false
            print("❌ 验证重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 重置密码
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: UserAttributes(password: newPassword))

            // 重置状态并标记为已认证
            needsPasswordSetup = false
            otpVerified = false
            isAuthenticated = true
            print("✅ 密码重置成功")

        } catch {
            errorMessage = "重置密码失败: \(error.localizedDescription)"
            print("❌ 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录
    /// - TODO: 实现 Sign in with Apple
    func signInWithApple() async {
        // TODO: 实现 Apple 登录
        // 1. 使用 AuthenticationServices 框架
        // 2. 获取 Apple ID credential
        // 3. 调用 supabase.auth.signInWithIdToken(credentials:)
        print("⚠️ Apple 登录功能待实现")
    }

    /// Google 登录
    /// - Parameter viewController: 用于展示 Google 登录界面的视图控制器
    func signInWithGoogle(presenting viewController: UIViewController) async {
        isLoading = true
        errorMessage = nil

        do {
            // 1. 配置 Google Sign In Client ID
            let clientID = "724126215320-jnfs4sron7qpm5j5cckmjn0e23o8ojjj.apps.googleusercontent.com"
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            print("📱 Google Sign In 配置完成")

            // 2. 调用 Google 登录（弹出账号选择界面）
            print("🔄 正在打开 Google 登录界面...")
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
            print("✅ Google 账号选择完成: \(result.user.profile?.email ?? "未知邮箱")")

            // 3. 获取 ID Token 和 Access Token
            guard let idToken = result.user.idToken?.tokenString else {
                print("❌ 无法获取 Google ID Token")
                throw NSError(
                    domain: "AuthManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "无法获取 Google 登录凭证"]
                )
            }
            let accessToken = result.user.accessToken.tokenString
            print("🔑 Token 获取成功")

            // 4. 使用 Supabase 验证 Google Token
            print("🔄 正在与 Supabase 验证...")
            let session = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )

            // 5. 登录成功，更新状态
            currentUser = session.user
            isAuthenticated = true
            print("✅ Google 登录成功，用户ID: \(session.user.id)")
            print("📧 邮箱: \(session.user.email ?? "无")")

        } catch let error as GIDSignInError {
            // Google 登录特定错误处理
            switch error.code {
            case .canceled:
                // 用户取消登录，不显示错误
                print("ℹ️ 用户取消了 Google 登录")
            case .hasNoAuthInKeychain:
                errorMessage = "未找到已保存的 Google 账号"
                print("❌ Google 登录错误: 未找到已保存的账号")
            case .EMM:
                errorMessage = "企业移动管理限制"
                print("❌ Google 登录错误: EMM 限制")
            default:
                errorMessage = "Google 登录失败: \(error.localizedDescription)"
                print("❌ Google 登录错误: \(error)")
            }
        } catch let error as NSError {
            // 网络错误或其他错误
            if error.domain == NSURLErrorDomain {
                errorMessage = "网络连接失败，请检查网络设置"
                print("❌ 网络错误: \(error)")
            } else {
                errorMessage = "登录失败: \(error.localizedDescription)"
                print("❌ 登录错误: \(error)")
            }
        }

        isLoading = false
    }

    // MARK: - 账户管理

    /// 删除账户
    /// 调用 Edge Function 删除当前用户账户
    func deleteAccount() async {
        isLoading = true
        errorMessage = nil

        do {
            // 1. 获取当前会话的 accessToken
            let session = try await supabase.auth.session
            let accessToken = session.accessToken

            // 2. 构建请求
            let url = URL(string: "https://eyprepalhwevgoryqyqf.supabase.co/functions/v1/delete-account")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // 3. 发送请求
            let (data, response) = try await URLSession.shared.data(for: request)

            // 4. 检查响应状态码
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "AuthManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "无效的服务器响应"]
                )
            }

            if httpResponse.statusCode == 200 {
                // 删除成功，重置所有认证状态
                currentUser = nil
                isAuthenticated = false
                otpSent = false
                otpVerified = false
                needsPasswordSetup = false
                pendingEmail = nil
                print("✅ 账户已成功删除")
            } else {
                // 解析错误信息
                if let errorResponse = try? JSONDecoder().decode(DeleteAccountErrorResponse.self, from: data) {
                    throw NSError(
                        domain: "AuthManager",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: errorResponse.error]
                    )
                } else {
                    throw NSError(
                        domain: "AuthManager",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "删除账户失败，状态码: \(httpResponse.statusCode)"]
                    )
                }
            }

        } catch let error as NSError {
            if error.domain == NSURLErrorDomain {
                errorMessage = "网络连接失败，请检查网络设置"
                print("❌ 删除账户网络错误: \(error)")
            } else {
                errorMessage = error.localizedDescription
                print("❌ 删除账户失败: \(error)")
            }
        } catch {
            errorMessage = "删除账户失败: \(error.localizedDescription)"
            print("❌ 删除账户失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 其他方法

    /// 登出
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()

            currentUser = nil
            isAuthenticated = false
            otpSent = false
            otpVerified = false
            needsPasswordSetup = false
            pendingEmail = nil
            print("✅ 已登出")

        } catch {
            errorMessage = "登出失败: \(error.localizedDescription)"
            print("❌ 登出失败: \(error)")
        }

        isLoading = false
    }

    /// 检查当前会话状态
    func checkSession() async {
        isLoading = true

        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            isAuthenticated = true
            print("✅ 会话有效，用户ID: \(session.user.id)")

        } catch {
            currentUser = nil
            isAuthenticated = false
            print("ℹ️ 无有效会话: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - 辅助方法

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 重置验证码状态
    func resetOTPState() {
        otpSent = false
        otpVerified = false
        needsPasswordSetup = false
        pendingEmail = nil
    }

    /// 切换认证模式
    /// - Parameter mode: 目标模式
    func switchMode(to mode: AuthMode) {
        authMode = mode
        clearError()
        resetOTPState()
    }
}
