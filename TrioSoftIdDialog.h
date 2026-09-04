#pragma once

#include <QDialog>
#include <QJsonObject>
#include <QString>
#include <functional>

class QLabel;
class QPushButton;
class QNetworkAccessManager;
class QTimer;

class TrioSoftIdDialog final : public QDialog
{
    Q_OBJECT

public:
    explicit TrioSoftIdDialog(QWidget *parent = nullptr);

private:
    void buildUi();
    void refreshClientConfig(std::function<void()> continuation);
    void restoreSession();
    void beginLogin();
    void requestDeviceCode();
    void pollDeviceToken();
    void refreshAccessToken();
    void fetchProfile();
    void fetchPremium();
    void syncLauncherLibrary();
    void applyProfile(const QJsonObject &profile);
    void applyPremium(const QJsonObject &payload);
    void setLoggedOut(const QString &message = QString());
    void setBusy(const QString &message);
    void saveRefreshToken(const QString &token);
    QString loadRefreshToken() const;
    void clearStoredSession();
    void revokeAndLogout();
    void loadAvatar(const QString &url);

    QNetworkAccessManager *m_network = nullptr;
    QTimer *m_pollTimer = nullptr;

    QLabel *m_avatar = nullptr;
    QLabel *m_title = nullptr;
    QLabel *m_identity = nullptr;
    QLabel *m_email = nullptr;
    QLabel *m_premium = nullptr;
    QLabel *m_status = nullptr;
    QLabel *m_code = nullptr;
    QPushButton *m_login = nullptr;
    QPushButton *m_account = nullptr;
    QPushButton *m_site = nullptr;
    QPushButton *m_logout = nullptr;

    QString m_clientId = QStringLiteral("tsc_mclauncher_windows_v100");
    QString m_deviceCode;
    QString m_accessToken;
    QString m_refreshToken;
    int m_pollIntervalSeconds = 5;
};
