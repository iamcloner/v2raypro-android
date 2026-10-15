# نرم‌افزار V2RayPro برای اندروید

<p align=center>
  <img src=assets/app_icon.png alt=لوگوی V2RayPro width=100 height=100 />
</p>

<p align=center>
  <strong>کلاینت پرسرعت، مدرن و پیشرفته V2Ray / Xray و Sing-box برای اندروید</strong>
</p>

<p align=center>
  <a href=README.md>English</a> • فارسی
</p>

---

## 🚀 قابلیت‌های کلیدی

- **سرویس بومی VpnService اندروید**: عملکرد پرسرعت با معماری بهینه Tun2socks و هماهنگی کامل با هسته سیستم‌عامل اندروید.
- **تأخیر واقعی (Real Delay ~600ms)**: اندازه‌گیری دقیق پینگ رفت و برگشت پروتکل (مشابه v2rayN و v2rayNG) بدون تاخیر کاذب و هماهنگی کامل قبل و بعد از اتصال.
- **منوی پایینی به سبک تلگرام**: طراحی مدرن همراه با نشانگر انتخاب بیضی‌شکل، شمارنده نشان‌ها و انیمیشن‌های روان.
- **پشتیبانی کامل از پروتکل‌ها**:
  - پروتکل VLESS (پشتیبانی از Reality، TLS، WebSocket، gRPC، HTTPUpgrade و XHTTP)
  - پروتکل VMess (پشتیبانی از WebSocket، TCP، mKCP و gRPC)
  - پروتکل‌های Trojan و Shadowsocks
  - کانفیگ‌های خروجی هسته Sing-box
- **اسکنر اختصاصی و فوق سریع CDN و کلادفلر**:
  - اسکن چندنخی (Multi-threaded) و غیرهمزمان (Async) با تست زنده تاخیر.
  - فعال‌سازی خودکار اسکنر برای دامنه‌ها و هاست‌های متصل به CDN.
  - پشتیبانی کامل از رنج‌های جدید کلادفلر نظیر 8.6.112.0/24.
- **تشخیص هوشمند کشور و پرچم‌ها**:
  - شناسایی نام‌های فارسی کشورها (آلمان، فرانسه، هلند، انگلیس، ترکیه، کانادا، آمریکا، فنلاند، سوئد، امارات، دبی و ...).
  - بررسی خودکار SNI و دامنه برای سرورهای پشت CDN و دیتابیس آفلاین GeoIP.
- **پروکسی تفکیکی برنامه‌ها (Per-App Routing / Split Tunneling)**:
  - امکان عبور دادن تمام برنامه‌ها یا انتخاب اپلیکیشن‌های خاص جهت عبور یا عدم عبور از فیلترشکن.
- **مدیریت پیشرفته سابسکریپشن و کانفیگ‌های رایگان**:
  - بروزرسانی با یک لمس، حذف کانفیگ‌های تکراری و نوار فیلتر اختصاصی بر اساس پرچم هر کشور.

---

## 📱 تصاویر برنامه

<p align=center>
  <img src=screenshots/navigation_bar.png alt=منوی ناوبری به سبک تلگرام width=450 />
</p>

<p align=center>
  <img src=screenshots/Dashboard.png alt=داشبورد width=410 />
  <img src=screenshots/CDN-scanner.png alt=اسکنر کلادفلر width=410 />
</p>

<p align=center>
  <img src=screenshots/Configs.png alt=کانفیگ‌ها width=410 />
  <img src=screenshots/Subs.png alt=سابسکریپشن width=410 />
</p>

---

## 📥 دانلود فایل نصبی APK

| نسخه | معماری | فایل نصبی | چکسام اعتبارسنجی |
| :---: | :---: | :---: | :---: |
| **v1.0.0** | تمام پردازنده‌ها (rm64-v8a, rmeabi-v7a, x86_64) | [دانلود مستقیم APK](release/v2raypro-v1.0.0-android.apk) | [sha256sum.txt](release/sha256sum.txt) |

### مراحل نصب
1. فایل 2raypro-v1.0.0-android.apk را از پوشه [release](release/v2raypro-v1.0.0-android.apk) دریافت نمایید.
2. روی فایل دریافتی در دستگاه اندرویدی خود (اندروید نسخه ۷.۰ به بالا) ضربه بزنید.
3. در صورت درخواست، گزینه نصب از منابع ناشناس (Allow from unknown sources) را تایید کنید.
4. برنامه را باز کرده و با لمس دکمه اتصال متصل شوید.

---

## 🛠️ کامپایل از سورس کد

### پیش‌نیازها
- فلاتر (نسخه ۳.۲۴.۰ به بالا)
- اندروید SDK (نسخه API 34+ و Build-Tools 36.0.0)
- جاوا JDK نسخه ۱۷ به بالا

### دستورات ساخت
`ash
# دریافت مخزن
git clone git@github.com:iamcloner/v2raypro-android.git
cd v2raypro-android

# دریافت پکیج‌ها
flutter pub get

# اجرای تست‌های اعتبارسنجی
flutter test

# ساخت نسخه نهایی APK
flutter build apk --release
`

---

## 📄 لایسنس
این پروژه تحت لایسنس GPL-3.0 منتشر شده است.
