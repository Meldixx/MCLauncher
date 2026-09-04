#include "TrioSoftIdDialog.h"

#include <QDateTime>
#include <QDesktopServices>
#include <QFont>
#include <QHBoxLayout>
#include <QJsonDocument>
#include <QList>
#include <QLocale>
#include <QJsonObject>
#include <QLabel>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPair>
#include <QPixmap>
#include <QPushButton>
#include <QSettings>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <QVBoxLayout>

#ifdef Q_OS_WIN
#include <windows.h>
#include <wincrypt.h>
#pragma comment(lib, "Crypt32.lib")
#endif

namespace {
const QUrl kBaseUrl(QStringLiteral("https://triosoft.xyz"));
const QString kClientConfigPath = QStringLiteral("/api/oauth/client-config/mclauncher");
const QString kDeviceCodePath = QStringLiteral("/api/oauth/device/code");
const QString kTokenPath = QStringLiteral("/api/oauth/token");
const QString kUserInfoPath = QStringLiteral("/api/oauth/userinfo");
const QString kPremiumPath = QStringLiteral("/api/oauth/premium");
const QString kLauncherLibraryPath = QStringLiteral("/api/oauth/library/mclauncher");
const QString kRevokePath = QStringLiteral("/api/oauth/revoke");
const QString kScope = QStringLiteral("openid profile email offline_access library");

QUrl endpoint(const QString &path)
{
    QUrl url = kBaseUrl;
    url.setPath(path);
    return url;
}

QByteArray encodedForm(const QList<QPair<QString, QString>> &items)
{
    QUrlQuery query;
    for (const auto &item : items)
        query.addQueryItem(item.first, item.second);
    return query.query(QUrl::FullyEncoded).toUtf8();
}

QJsonObject parseObject(const QByteArray &payload)
{
    QJsonParseError error{};
    const auto document = QJsonDocument::fromJson(payload, &error);
    if (error.error != QJsonParseError::NoError || !document.isObject())
        return {};
    return document.object();
}

QString errorDescription(const QJsonObject &object, const QString &fallback)
{
    const auto description = object.value(QStringLiteral("error_description")).toString();
    if (!description.isEmpty())
        return description;
    const auto error = object.value(QStringLiteral("error")).toString();
    return error.isEmpty() ? fallback : error;
}

QString protectForCurrentUser(const QString &value)
{
#ifdef Q_OS_WIN
    const QByteArray plain = value.toUtf8();
    if (plain.isEmpty())
        return {};
    DATA_BLOB inBlob{};
    inBlob.cbData = static_cast<DWORD>(plain.size());
    inBlob.pbData = reinterpret_cast<BYTE *>(const_cast<char *>(plain.constData()));
    DATA_BLOB outBlob{};
    if (!CryptProtectData(&inBlob, L"MCLauncher TrioSoft ID", nullptr, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &outBlob))
        return {};
    const QByteArray protectedBytes(reinterpret_cast<const char *>(outBlob.pbData), static_cast<int>(outBlob.cbData));
    LocalFree(outBlob.pbData);
    return QString::fromLatin1(protectedBytes.toBase64());
#else
    Q_UNUSED(value)
    return {};
#endif
}

QString unprotectForCurrentUser(const QString &value)
{
#ifdef Q_OS_WIN
    const QByteArray protectedBytes = QByteArray::fromBase64(value.toLatin1());
    if (protectedBytes.isEmpty())
        return {};
    DATA_BLOB inBlob{};
    inBlob.cbData = static_cast<DWORD>(protectedBytes.size());
    inBlob.pbData = reinterpret_cast<BYTE *>(const_cast<char *>(protectedBytes.constData()));
    DATA_BLOB outBlob{};
    if (!CryptUnprotectData(&inBlob, nullptr, nullptr, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &outBlob))
        return {};
    const QByteArray plain(reinterpret_cast<const char *>(outBlob.pbData), static_cast<int>(outBlob.cbData));
    LocalFree(outBlob.pbData);
    return QString::fromUtf8(plain);
#else
    Q_UNUSED(value)
    return {};
#endif
}

QNetworkRequest formRequest(const QUrl &url)
{
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/x-www-form-urlencoded"));
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Cache-Control", "no-cache");
    request.setRawHeader("User-Agent", "MCLauncher/1.0.0 TrioSoftID");
    return request;
}

QNetworkRequest bearerRequest(const QUrl &url, const QString &token)
{
    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Cache-Control", "no-cache");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + token.toUtf8());
    request.setRawHeader("User-Agent", "MCLauncher/1.0.0 TrioSoftID");
    return request;
}
}

TrioSoftIdDialog::TrioSoftIdDialog(QWidget *parent) : QDialog(parent)
{
    setWindowTitle(tr("TrioSoft ID — MCLauncher"));
    setMinimumWidth(520);
    setModal(true);

    m_network = new QNetworkAccessManager(this);
    m_pollTimer = new QTimer(this);
    m_pollTimer->setSingleShot(false);
    connect(m_pollTimer, &QTimer::timeout, this, &TrioSoftIdDialog::pollDeviceToken);

    buildUi();
    QTimer::singleShot(0, this, [this] { restoreSession(); });
}

void TrioSoftIdDialog::buildUi()
{
    auto *root = new QVBoxLayout(this);
    root->setContentsMargins(24, 24, 24, 24);
    root->setSpacing(14);

    auto *header = new QHBoxLayout();
    m_avatar = new QLabel(this);
    m_avatar->setFixedSize(72, 72);
    m_avatar->setAlignment(Qt::AlignCenter);
    m_avatar->setStyleSheet(QStringLiteral("border:1px solid palette(mid); border-radius:18px; font-size:28px;"));
    m_avatar->setText(QStringLiteral("TS"));
    header->addWidget(m_avatar, 0, Qt::AlignTop);

    auto *headText = new QVBoxLayout();
    m_title = new QLabel(tr("TrioSoft ID"), this);
    QFont titleFont = m_title->font();
    titleFont.setPointSize(titleFont.pointSize() + 4);
    titleFont.setBold(true);
    m_title->setFont(titleFont);
    headText->addWidget(m_title);
    auto *description = new QLabel(tr("Единый аккаунт MCLauncher и экосистемы TrioSoft."), this);
    description->setWordWrap(true);
    description->setStyleSheet(QStringLiteral("color: palette(mid);"));
    headText->addWidget(description);
    header->addLayout(headText, 1);
    root->addLayout(header);

    m_identity = new QLabel(tr("Вы не вошли в TrioSoft ID."), this);
    m_identity->setWordWrap(true);
    root->addWidget(m_identity);

    m_email = new QLabel(this);
    m_email->setWordWrap(true);
    m_email->hide();
    root->addWidget(m_email);

    m_premium = new QLabel(tr("Статус: FREE"), this);
    m_premium->setWordWrap(true);
    root->addWidget(m_premium);

    m_code = new QLabel(this);
    m_code->setTextFormat(Qt::RichText);
    m_code->setTextInteractionFlags(Qt::TextSelectableByMouse);
    m_code->setAlignment(Qt::AlignCenter);
    m_code->setStyleSheet(QStringLiteral("padding:12px; border:1px solid palette(mid); border-radius:12px; font-size:18px;"));
    m_code->hide();
    root->addWidget(m_code);

    m_status = new QLabel(this);
    m_status->setWordWrap(true);
    m_status->setStyleSheet(QStringLiteral("color: palette(mid);"));
    root->addWidget(m_status);

    auto *primaryRow = new QHBoxLayout();
    m_login = new QPushButton(tr("Войти через TrioSoft ID"), this);
    m_login->setDefault(true);
    connect(m_login, &QPushButton::clicked, this, &TrioSoftIdDialog::beginLogin);
    primaryRow->addWidget(m_login, 1);

    m_account = new QPushButton(tr("Управление аккаунтом"), this);
    connect(m_account, &QPushButton::clicked, this, [] { QDesktopServices::openUrl(QUrl(QStringLiteral("https://triosoft.xyz/account"))); });
    m_account->hide();
    primaryRow->addWidget(m_account);
    root->addLayout(primaryRow);

    auto *secondaryRow = new QHBoxLayout();
    m_site = new QPushButton(tr("Сайт TrioSoft"), this);
    connect(m_site, &QPushButton::clicked, this, [] { QDesktopServices::openUrl(kBaseUrl); });
    secondaryRow->addWidget(m_site);

    m_logout = new QPushButton(tr("Выйти"), this);
    connect(m_logout, &QPushButton::clicked, this, &TrioSoftIdDialog::revokeAndLogout);
    m_logout->hide();
    secondaryRow->addWidget(m_logout);

    auto *close = new QPushButton(tr("Закрыть"), this);
    connect(close, &QPushButton::clicked, this, &QDialog::accept);
    secondaryRow->addWidget(close);
    root->addLayout(secondaryRow);
}

void TrioSoftIdDialog::refreshClientConfig(std::function<void()> continuation)
{
    QNetworkRequest request(endpoint(kClientConfigPath));
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Cache-Control", "no-cache");
    auto *reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, continuation = std::move(continuation)]() mutable {
        const auto object = parseObject(reply->readAll());
        if (reply->error() == QNetworkReply::NoError) {
            const QString id = object.value(QStringLiteral("client_id")).toString(object.value(QStringLiteral("clientId")).toString());
            if (!id.isEmpty()) {
                m_clientId = id;
                QSettings settings(QStringLiteral("TrioSoft"), QStringLiteral("MCLauncher"));
                settings.setValue(QStringLiteral("TrioSoftID/clientId"), id);
            }
        } else {
            QSettings settings(QStringLiteral("TrioSoft"), QStringLiteral("MCLauncher"));
            const QString cached = settings.value(QStringLiteral("TrioSoftID/clientId")).toString();
            if (!cached.isEmpty())
                m_clientId = cached;
        }
        reply->deleteLater();
        if (continuation)
            continuation();
    });
}

void TrioSoftIdDialog::restoreSession()
{
    setBusy(tr("Проверяем TrioSoft ID…"));
    refreshClientConfig([this] {
        m_refreshToken = loadRefreshToken();
        if (m_refreshToken.isEmpty()) {
            setLoggedOut();
            return;
        }
        refreshAccessToken();
    });
}

void TrioSoftIdDialog::beginLogin()
{
    m_login->setEnabled(false);
    m_code->hide();
    setBusy(tr("Подготавливаем вход через TrioSoft ID…"));
    refreshClientConfig([this] { requestDeviceCode(); });
}

void TrioSoftIdDialog::requestDeviceCode()
{
    const QByteArray body = encodedForm({
        { QStringLiteral("client_id"), m_clientId },
        { QStringLiteral("scope"), kScope }
    });
    auto *reply = m_network->post(formRequest(endpoint(kDeviceCodePath)), body);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        const auto object = parseObject(reply->readAll());
        if (reply->error() != QNetworkReply::NoError) {
            const QString message = errorDescription(object, tr("Не удалось начать вход в TrioSoft ID."));
            reply->deleteLater();
            setLoggedOut(message);
            return;
        }

        m_deviceCode = object.value(QStringLiteral("device_code")).toString();
        const QString userCode = object.value(QStringLiteral("user_code")).toString();
        const QString verification = object.value(QStringLiteral("verification_uri_complete")).toString();
        m_pollIntervalSeconds = qMax(2, object.value(QStringLiteral("interval")).toInt(5));
        reply->deleteLater();

        if (m_deviceCode.isEmpty() || verification.isEmpty()) {
            setLoggedOut(tr("Сервер TrioSoft ID вернул неполный Device Flow ответ."));
            return;
        }

        m_code->setText(tr("Код подтверждения: <b>%1</b>").arg(userCode.toHtmlEscaped()));
        m_code->show();
        m_status->setText(tr("Браузер открыт. Войдите в TrioSoft ID и подтвердите доступ для MCLauncher."));
        QDesktopServices::openUrl(QUrl(verification));
        m_pollTimer->start(m_pollIntervalSeconds * 1000);
        QTimer::singleShot(400, this, &TrioSoftIdDialog::pollDeviceToken);
    });
}

void TrioSoftIdDialog::pollDeviceToken()
{
    if (m_deviceCode.isEmpty())
        return;

    const QByteArray body = encodedForm({
        { QStringLiteral("grant_type"), QStringLiteral("urn:ietf:params:oauth:grant-type:device_code") },
        { QStringLiteral("client_id"), m_clientId },
        { QStringLiteral("device_code"), m_deviceCode }
    });
    auto *reply = m_network->post(formRequest(endpoint(kTokenPath)), body);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        const auto object = parseObject(reply->readAll());
        const QString oauthError = object.value(QStringLiteral("error")).toString();
        if (reply->error() != QNetworkReply::NoError || object.contains(QStringLiteral("error"))) {
            reply->deleteLater();
            if (oauthError == QStringLiteral("authorization_pending"))
                return;
            if (oauthError == QStringLiteral("slow_down")) {
                m_pollIntervalSeconds += 5;
                m_pollTimer->setInterval(m_pollIntervalSeconds * 1000);
                return;
            }
            m_pollTimer->stop();
            m_deviceCode.clear();
            setLoggedOut(errorDescription(object, tr("Не удалось завершить вход в TrioSoft ID.")));
            return;
        }

        m_pollTimer->stop();
        m_deviceCode.clear();
        m_accessToken = object.value(QStringLiteral("access_token")).toString();
        m_refreshToken = object.value(QStringLiteral("refresh_token")).toString();
        reply->deleteLater();
        if (m_accessToken.isEmpty()) {
            setLoggedOut(tr("TrioSoft ID не вернул access token."));
            return;
        }
        if (!m_refreshToken.isEmpty())
            saveRefreshToken(m_refreshToken);
        m_code->hide();
        setBusy(tr("Вход выполнен. Загружаем профиль…"));
        fetchProfile();
        fetchPremium();
        syncLauncherLibrary();
    });
}

void TrioSoftIdDialog::refreshAccessToken()
{
    const QByteArray body = encodedForm({
        { QStringLiteral("grant_type"), QStringLiteral("refresh_token") },
        { QStringLiteral("client_id"), m_clientId },
        { QStringLiteral("refresh_token"), m_refreshToken }
    });
    auto *reply = m_network->post(formRequest(endpoint(kTokenPath)), body);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        const auto object = parseObject(reply->readAll());
        if (reply->error() != QNetworkReply::NoError || object.contains(QStringLiteral("error"))) {
            reply->deleteLater();
            clearStoredSession();
            m_accessToken.clear();
            m_refreshToken.clear();
            setLoggedOut(tr("Сессия TrioSoft ID истекла. Войдите снова."));
            return;
        }
        m_accessToken = object.value(QStringLiteral("access_token")).toString();
        const QString rotated = object.value(QStringLiteral("refresh_token")).toString();
        if (!rotated.isEmpty()) {
            m_refreshToken = rotated;
            saveRefreshToken(rotated);
        }
        reply->deleteLater();
        fetchProfile();
        fetchPremium();
        syncLauncherLibrary();
    });
}

void TrioSoftIdDialog::fetchProfile()
{
    if (m_accessToken.isEmpty())
        return;
    auto *reply = m_network->get(bearerRequest(endpoint(kUserInfoPath), m_accessToken));
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        const auto object = parseObject(reply->readAll());
        if (reply->error() != QNetworkReply::NoError) {
            reply->deleteLater();
            setLoggedOut(tr("Не удалось получить профиль TrioSoft ID."));
            return;
        }
        reply->deleteLater();
        applyProfile(object);
    });
}

void TrioSoftIdDialog::fetchPremium()
{
    if (m_accessToken.isEmpty())
        return;
    auto *reply = m_network->get(bearerRequest(endpoint(kPremiumPath), m_accessToken));
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        const auto object = parseObject(reply->readAll());
        reply->deleteLater();
        if (!object.isEmpty())
            applyPremium(object);
    });
}

void TrioSoftIdDialog::syncLauncherLibrary()
{
    if (m_accessToken.isEmpty())
        return;

    QNetworkRequest request = bearerRequest(endpoint(kLauncherLibraryPath), m_accessToken);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    const QJsonObject body{
        { QStringLiteral("installedVersion"), QStringLiteral("1.0.0") },
        { QStringLiteral("lastDownloadedVersion"), QStringLiteral("1.0.0") },
        { QStringLiteral("lastAsset"), QStringLiteral("setup") }
    };
    auto *reply = m_network->put(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
}

void TrioSoftIdDialog::applyProfile(const QJsonObject &profile)
{
    const QString name = profile.value(QStringLiteral("name")).toString();
    const QString username = profile.value(QStringLiteral("preferred_username")).toString();
    const QString email = profile.value(QStringLiteral("email")).toString();
    const QString role = profile.value(QStringLiteral("triosoft_role")).toString(QStringLiteral("user"));

    const QString display = !name.isEmpty() ? name : (!username.isEmpty() ? username : tr("Пользователь TrioSoft"));
    m_identity->setText(username.isEmpty() ? display : QStringLiteral("%1  ·  @%2").arg(display, username));
    m_email->setText(email.isEmpty() ? tr("TrioSoft ID · роль: %1").arg(role) : tr("%1 · роль: %2").arg(email, role));
    m_email->show();
    m_status->setText(tr("Вы вошли в MCLauncher через TrioSoft ID."));
    m_login->hide();
    m_account->show();
    m_logout->show();
    m_code->hide();

    const QString picture = profile.value(QStringLiteral("picture")).toString();
    if (!picture.isEmpty())
        loadAvatar(picture);
}

void TrioSoftIdDialog::applyPremium(const QJsonObject &payload)
{
    const QJsonObject premium = payload.value(QStringLiteral("premium")).toObject();
    const bool active = premium.value(QStringLiteral("active")).toBool(payload.value(QStringLiteral("triosoft_premium")).toBool(false));
    const QString status = premium.value(QStringLiteral("status")).toString(payload.value(QStringLiteral("triosoft_premium_status")).toString());
    const QString expires = premium.value(QStringLiteral("expiresAt")).toString(payload.value(QStringLiteral("triosoft_premium_expires_at")).toString());

    if (active) {
        QString text = tr("Статус: PREMIUM");
        const auto expiry = QDateTime::fromString(expires, Qt::ISODate);
        if (expiry.isValid())
            text += tr(" · до %1").arg(QLocale().toString(expiry.toLocalTime().date(), QLocale::ShortFormat));
        m_premium->setText(text);
        m_premium->setStyleSheet(QStringLiteral("font-weight:700; color:#d6a928;"));
    } else {
        m_premium->setText(status.isEmpty() ? tr("Статус: FREE") : tr("Статус: FREE · %1").arg(status));
        m_premium->setStyleSheet(QString());
    }
}

void TrioSoftIdDialog::setLoggedOut(const QString &message)
{
    m_pollTimer->stop();
    m_deviceCode.clear();
    m_login->show();
    m_login->setEnabled(true);
    m_account->hide();
    m_logout->hide();
    m_code->hide();
    m_identity->setText(tr("Вы не вошли в TrioSoft ID."));
    m_email->hide();
    m_premium->setText(tr("Статус: FREE"));
    m_premium->setStyleSheet(QString());
    m_status->setText(message);
    m_avatar->setPixmap(QPixmap());
    m_avatar->setText(QStringLiteral("TS"));
}

void TrioSoftIdDialog::setBusy(const QString &message)
{
    m_login->setEnabled(false);
    m_status->setText(message);
}

void TrioSoftIdDialog::saveRefreshToken(const QString &token)
{
    const QString protectedValue = protectForCurrentUser(token);
    if (protectedValue.isEmpty())
        return;
    QSettings settings(QStringLiteral("TrioSoft"), QStringLiteral("MCLauncher"));
    settings.setValue(QStringLiteral("TrioSoftID/refreshTokenDpapi"), protectedValue);
    settings.setValue(QStringLiteral("TrioSoftID/clientId"), m_clientId);
    settings.sync();
}

QString TrioSoftIdDialog::loadRefreshToken() const
{
    QSettings settings(QStringLiteral("TrioSoft"), QStringLiteral("MCLauncher"));
    const QString stored = settings.value(QStringLiteral("TrioSoftID/refreshTokenDpapi")).toString();
    return unprotectForCurrentUser(stored);
}

void TrioSoftIdDialog::clearStoredSession()
{
    QSettings settings(QStringLiteral("TrioSoft"), QStringLiteral("MCLauncher"));
    settings.remove(QStringLiteral("TrioSoftID/refreshTokenDpapi"));
    settings.sync();
}

void TrioSoftIdDialog::revokeAndLogout()
{
    const QString token = !m_refreshToken.isEmpty() ? m_refreshToken : m_accessToken;
    if (!token.isEmpty()) {
        const QByteArray body = encodedForm({ { QStringLiteral("token"), token } });
        auto *reply = m_network->post(formRequest(endpoint(kRevokePath)), body);
        connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
    }
    clearStoredSession();
    m_accessToken.clear();
    m_refreshToken.clear();
    setLoggedOut(tr("Вы вышли из TrioSoft ID."));
}

void TrioSoftIdDialog::loadAvatar(const QString &url)
{
    auto *reply = m_network->get(QNetworkRequest(QUrl(url)));
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        const QByteArray bytes = reply->readAll();
        reply->deleteLater();
        QPixmap pixmap;
        if (pixmap.loadFromData(bytes)) {
            m_avatar->setText(QString());
            m_avatar->setPixmap(pixmap.scaled(m_avatar->size(), Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation));
        }
    });
}
