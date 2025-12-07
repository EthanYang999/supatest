//
//  AuthView.swift
//  supatest
//
//  EarthLord 游戏认证页面
//  包含登录、注册、找回密码功能
//

import SwiftUI

// MARK: - 注册步骤枚举

/// 注册流程步骤
enum RegisterStep: Int, CaseIterable {
    case email = 1      // 输入邮箱
    case verify = 2     // 验证验证码
    case password = 3   // 设置密码
}

// MARK: - AuthView

struct AuthView: View {
    @StateObject private var authManager = AuthManager.shared

    // MARK: - 状态属性

    /// 当前选中的Tab（0: 登录, 1: 注册）
    @State private var selectedTab = 0

    /// 登录表单
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    /// 注册表单
    @State private var registerEmail = ""
    @State private var registerOTP = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""
    @State private var registerStep: RegisterStep = .email

    /// 找回密码表单
    @State private var resetEmail = ""
    @State private var resetOTP = ""
    @State private var resetPassword = ""
    @State private var resetConfirmPassword = ""
    @State private var resetStep = 1

    /// 弹窗状态
    @State private var showResetPasswordSheet = false
    @State private var showToast = false
    @State private var toastMessage = ""

    /// 重发验证码倒计时
    @State private var resendCountdown = 0
    @State private var resendTimer: Timer?

    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient

            ScrollView {
                VStack(spacing: 30) {
                    // Logo 和标题
                    headerSection
                        .padding(.top, 60)

                    // Tab 切换
                    tabSelector
                        .padding(.horizontal, 40)

                    // 内容区域
                    if selectedTab == 0 {
                        loginSection
                    } else {
                        registerSection
                    }

                    // 分隔线
                    dividerSection
                        .padding(.top, 20)

                    // 第三方登录
                    socialLoginSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }

            // Toast 提示
            if showToast {
                toastView
            }
        }
        .sheet(isPresented: $showResetPasswordSheet) {
            resetPasswordSheet
        }
        .onDisappear {
            resendTimer?.invalidate()
        }
    }

    // MARK: - 背景渐变

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "1A1A2E"),
                Color(hex: "16213E"),
                Color(hex: "0F0F1A")
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - 头部区域

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Logo 占位
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            // 标题
            Text("地球新主")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(ApocalypseTheme.text)

            Text("在废土中行走，成为新的主宰")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - Tab 选择器

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "登录", index: 0)
            tabButton(title: "注册", index: 1)
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(25)
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
                authManager.clearError()
            }
        }) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(selectedTab == index ? .white : ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    selectedTab == index
                    ? ApocalypseTheme.primary
                    : Color.clear
                )
                .cornerRadius(25)
        }
    }

    // MARK: - 登录区域

    private var loginSection: some View {
        VStack(spacing: 16) {
            // 邮箱输入
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $loginEmail,
                keyboardType: .emailAddress
            )

            // 密码输入
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $loginPassword
            )

            // 错误提示
            if let error = authManager.errorMessage {
                errorText(error)
            }

            // 登录按钮
            PrimaryButton(
                title: "登录",
                isLoading: authManager.isLoading
            ) {
                Task {
                    await authManager.signIn(email: loginEmail, password: loginPassword)
                }
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty)

            // 忘记密码
            Button(action: {
                showResetPasswordSheet = true
            }) {
                Text("忘记密码？")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
    }

    // MARK: - 注册区域

    private var registerSection: some View {
        VStack(spacing: 16) {
            // 步骤指示器
            stepIndicator

            // 根据步骤显示不同内容
            switch registerStep {
            case .email:
                registerEmailStep
            case .verify:
                registerVerifyStep
            case .password:
                registerPasswordStep
            }

            // 错误提示
            if let error = authManager.errorMessage {
                errorText(error)
            }
        }
    }

    /// 步骤指示器
    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(RegisterStep.allCases, id: \.rawValue) { step in
                HStack(spacing: 4) {
                    Circle()
                        .fill(step.rawValue <= registerStep.rawValue
                              ? ApocalypseTheme.primary
                              : Color.white.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text(verbatim: "\(step.rawValue)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )

                    if step != .password {
                        Rectangle()
                            .fill(step.rawValue < registerStep.rawValue
                                  ? ApocalypseTheme.primary
                                  : Color.white.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: 40)
                    }
                }
            }
        }
        .padding(.bottom, 10)
    }

    /// 注册第一步：输入邮箱
    private var registerEmailStep: some View {
        VStack(spacing: 16) {
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            PrimaryButton(
                title: "发送验证码",
                isLoading: authManager.isLoading
            ) {
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                    if authManager.otpSent {
                        withAnimation {
                            registerStep = .verify
                        }
                        startResendCountdown()
                    }
                }
            }
            .disabled(registerEmail.isEmpty || !isValidEmail(registerEmail))
        }
    }

    /// 注册第二步：验证验证码
    private var registerVerifyStep: some View {
        VStack(spacing: 16) {
            Text("验证码已发送至")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(registerEmail)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.text)

            // 验证码输入
            OTPTextField(code: $registerOTP)

            // 重发倒计时
            if resendCountdown > 0 {
                Text("\(resendCountdown)秒后可重新发送", tableName: nil, bundle: .main, comment: "")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } else {
                Button(action: {
                    Task {
                        await authManager.sendRegisterOTP(email: registerEmail)
                        if authManager.otpSent {
                            startResendCountdown()
                        }
                    }
                }) {
                    Text("重新发送验证码")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }

            PrimaryButton(
                title: "验证",
                isLoading: authManager.isLoading
            ) {
                Task {
                    await authManager.verifyRegisterOTP(email: registerEmail, code: registerOTP)
                    if authManager.otpVerified {
                        withAnimation {
                            registerStep = .password
                        }
                    }
                }
            }
            .disabled(registerOTP.count != 6)

            // 返回上一步
            Button(action: {
                withAnimation {
                    registerStep = .email
                    authManager.resetOTPState()
                }
            }) {
                Text("返回修改邮箱")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    /// 注册第三步：设置密码
    private var registerPasswordStep: some View {
        VStack(spacing: 16) {
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "设置密码（至少6位）",
                text: $registerPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $registerConfirmPassword
            )

            // 密码不匹配提示
            if !registerConfirmPassword.isEmpty && registerPassword != registerConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            PrimaryButton(
                title: "完成注册",
                isLoading: authManager.isLoading
            ) {
                Task {
                    await authManager.completeRegistration(password: registerPassword)
                    // 注册完成后 AuthManager 会更新 isAuthenticated，自动跳转主页
                }
            }
            .disabled(
                registerPassword.count < 6 ||
                registerPassword != registerConfirmPassword
            )
        }
    }

    // MARK: - 分隔线

    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)

            Text("或者使用以下方式登录")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .fixedSize()

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
        }
    }

    // MARK: - 第三方登录

    private var socialLoginSection: some View {
        VStack(spacing: 12) {
            // Apple 登录（占位）
            Button(action: {
                showToastMessage("Apple 登录即将开放")
            }) {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20))
                    Text("通过 Apple 登录")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(12)
            }

            // Google 登录（真正实现）
            GoogleSignInButton()
                .environmentObject(authManager)
        }
    }

    // MARK: - 找回密码弹窗

    private var resetPasswordSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 步骤指示
                        Text("步骤 \(resetStep) / 3")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .padding(.top, 20)

                        if resetStep == 1 {
                            // 第一步：输入邮箱
                            resetEmailStep
                        } else if resetStep == 2 {
                            // 第二步：验证验证码
                            resetVerifyStep
                        } else {
                            // 第三步：设置新密码
                            resetNewPasswordStep
                        }

                        // 错误提示
                        if let error = authManager.errorMessage {
                            errorText(error)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showResetPasswordSheet = false
                        resetResetPasswordForm()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// 找回密码第一步
    private var resetEmailStep: some View {
        VStack(spacing: 16) {
            Text("请输入注册时使用的邮箱")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $resetEmail,
                keyboardType: .emailAddress
            )

            PrimaryButton(
                title: "发送验证码",
                isLoading: authManager.isLoading
            ) {
                Task {
                    await authManager.sendResetOTP(email: resetEmail)
                    if authManager.otpSent {
                        withAnimation {
                            resetStep = 2
                        }
                        startResendCountdown()
                    }
                }
            }
            .disabled(resetEmail.isEmpty || !isValidEmail(resetEmail))
        }
    }

    /// 找回密码第二步
    private var resetVerifyStep: some View {
        VStack(spacing: 16) {
            Text("验证码已发送至")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(resetEmail)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.text)

            OTPTextField(code: $resetOTP)

            // 重发倒计时
            if resendCountdown > 0 {
                Text("\(resendCountdown)秒后可重新发送", tableName: nil, bundle: .main, comment: "")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } else {
                Button(action: {
                    Task {
                        await authManager.sendResetOTP(email: resetEmail)
                        if authManager.otpSent {
                            startResendCountdown()
                        }
                    }
                }) {
                    Text("重新发送验证码")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }

            PrimaryButton(
                title: "验证",
                isLoading: authManager.isLoading
            ) {
                Task {
                    await authManager.verifyResetOTP(email: resetEmail, code: resetOTP)
                    if authManager.otpVerified {
                        withAnimation {
                            resetStep = 3
                        }
                    }
                }
            }
            .disabled(resetOTP.count != 6)
        }
    }

    /// 找回密码第三步
    private var resetNewPasswordStep: some View {
        VStack(spacing: 16) {
            Text("请设置新密码")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $resetPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $resetConfirmPassword
            )

            if !resetConfirmPassword.isEmpty && resetPassword != resetConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            PrimaryButton(
                title: "重置密码",
                isLoading: authManager.isLoading
            ) {
                Task {
                    await authManager.resetPassword(newPassword: resetPassword)
                    if authManager.errorMessage == nil {
                        showResetPasswordSheet = false
                        resetResetPasswordForm()
                        // 密码重置成功后 isAuthenticated = true，用户自动进入主页
                    }
                }
            }
            .disabled(
                resetPassword.count < 6 ||
                resetPassword != resetConfirmPassword
            )
        }
    }

    // MARK: - Toast 视图

    private var toastView: some View {
        VStack {
            Spacer()

            Text(toastMessage)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(25)
                .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: showToast)
    }

    // MARK: - 辅助视图

    private func errorText(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
            Text(message)
        }
        .font(.caption)
        .foregroundColor(ApocalypseTheme.danger)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.danger.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - 辅助方法

    /// 验证邮箱格式
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    /// 开始重发倒计时
    private func startResendCountdown() {
        resendCountdown = 60
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                resendTimer?.invalidate()
            }
        }
    }

    /// 显示 Toast
    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }

    /// 重置找回密码表单
    private func resetResetPasswordForm() {
        resetEmail = ""
        resetOTP = ""
        resetPassword = ""
        resetConfirmPassword = ""
        resetStep = 1
        authManager.resetOTPState()
        authManager.clearError()
    }
}

// MARK: - 自定义输入框组件

/// 自定义文本输入框
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 20)

            TextField(text: $text, prompt: Text(placeholder).foregroundColor(ApocalypseTheme.textSecondary)) {}
                .foregroundColor(ApocalypseTheme.text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

/// 自定义密码输入框
struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isSecure = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 20)

            if isSecure {
                SecureField(text: $text, prompt: Text(placeholder).foregroundColor(ApocalypseTheme.textSecondary)) {}
                    .foregroundColor(ApocalypseTheme.text)
            } else {
                TextField(text: $text, prompt: Text(placeholder).foregroundColor(ApocalypseTheme.textSecondary)) {}
                    .foregroundColor(ApocalypseTheme.text)
                    .autocapitalization(.none)
            }

            Button(action: { isSecure.toggle() }) {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

/// OTP 验证码输入框
struct OTPTextField: View {
    @Binding var code: String
    let length: Int = 6

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<length, id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 45, height: 55)

                    if index < code.count {
                        let charIndex = code.index(code.startIndex, offsetBy: index)
                        Text(String(code[charIndex]))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.text)
                    }
                }
            }
        }
        .overlay(
            TextField(text: $code) {}
                .keyboardType(.numberPad)
                .foregroundColor(.clear)
                .accentColor(.clear)
                .onChange(of: code) { _, newValue in
                    // 限制只能输入数字且最多6位
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count <= length {
                        code = filtered
                    } else {
                        code = String(filtered.prefix(length))
                    }
                }
        )
    }
}

/// 主按钮
struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isLoading ? "处理中..." : title)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1)
    }
}

// MARK: - Preview

#Preview {
    AuthView()
}
