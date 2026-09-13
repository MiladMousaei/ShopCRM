class AppStrings {
  AppStrings._();

  // نام اپ
  static const String appName = 'فروشگاه هوشمند';
  static const String appVersion = 'نسخه ۱.۰.۳';

  // ورود
  static const String login = 'ورود به سیستم';
  static const String username = 'نام کاربری';
  static const String password = 'رمز عبور';
  static const String loginButton = 'ورود';
  static const String loginError = 'نام کاربری یا رمز عبور اشتباه است';
  static const String rememberMe = 'مرا به خاطر بسپار';

  // ناوبری
  static const String dashboard = 'داشبورد';
  static const String newInvoice = 'فاکتور جدید';
  static const String invoices = 'فاکتورها';
  static const String products = 'محصولات';
  static const String inventory = 'انبار';
  static const String customers = 'مشتریان';
  static const String reports = 'گزارش‌ها';
  static const String settings = 'تنظیمات';

  // داشبورد
  static const String todaySales = 'فروش امروز';
  static const String totalInventory = 'موجودی کل';
  static const String lowStockAlert = 'هشدار کمبود';
  static const String debtors = 'بدهکاران';
  static const String recentInvoices = 'آخرین فاکتورها';
  static const String lowStockProducts = 'محصولات زیر حداقل موجودی';
  static const String weeklySalesChart = 'نمودار فروش ۷ روز اخیر';

  // فاکتور
  static const String invoice = 'فاکتور';
  static const String invoiceNumber = 'شماره فاکتور';
  static const String invoiceDate = 'تاریخ';
  static const String totalAmount = 'جمع کل';
  static const String discount = 'تخفیف';
  static const String tax = 'مالیات';
  static const String finalAmount = 'مبلغ نهایی';
  static const String paymentMethod = 'روش پرداخت';
  static const String cash = 'نقد';
  static const String card = 'کارت';
  static const String credit = 'نسیه';
  static const String submitAndPrint = 'ثبت و پرینت';
  static const String submitOnly = 'ثبت بدون پرینت';
  static const String scanBarcode = 'اسکن بارکد';
  static const String searchProduct = 'جستجوی محصول';
  static const String selectCustomer = 'انتخاب مشتری';
  static const String cartEmpty = 'سبد خرید خالی است';
  static const String addToCart = 'افزودن به سبد';
  static const String removeFromCart = 'حذف از سبد';
  static const String quantity = 'تعداد';
  static const String unitPrice = 'قیمت واحد';
  static const String subtotal = 'جمع جزء';
  static const String items = 'قلم';
  static const String discountPercent = 'درصد';
  static const String discountAmount = 'مبلغ';

  // محصول
  static const String product = 'محصول';
  static const String productName = 'نام محصول';
  static const String barcode = 'بارکد';
  static const String category = 'دسته‌بندی';
  static const String purchasePrice = 'قیمت خرید';
  static const String sellPrice = 'قیمت فروش';
  static const String stockQuantity = 'موجودی';
  static const String minStockAlert = 'حداقل موجودی';
  static const String addProduct = 'افزودن محصول';
  static const String editProduct = 'ویرایش محصول';
  static const String deleteProduct = 'حذف محصول';
  static const String productNotFound = 'محصول یافت نشد';
  static const String barcodeNotFound = 'بارکد در سیستم ثبت نشده';

  // مشتری
  static const String customer = 'مشتری';
  static const String customerName = 'نام مشتری';
  static const String phone = 'شماره تماس';
  static const String address = 'آدرس';
  static const String creditLimit = 'سقف اعتبار';
  static const String totalDebt = 'بدهی کل';
  static const String addCustomer = 'افزودن مشتری';
  static const String noCustomer = 'بدون مشتری';
  static const String purchaseHistory = 'تاریخچه خرید';

  // انبار
  static const String adjustStock = 'تنظیم موجودی';
  static const String stockIn = 'ورود کالا';
  static const String stockOut = 'خروج کالا';
  static const String stockAdjust = 'تعدیل موجودی';
  static const String reason = 'دلیل';

  // گزارش
  static const String report = 'گزارش';
  static const String fromDate = 'از تاریخ';
  static const String toDate = 'تا تاریخ';
  static const String daily = 'روزانه';
  static const String weekly = 'هفتگی';
  static const String monthly = 'ماهانه';
  static const String topProducts = 'پرفروش‌ترین محصولات';
  static const String exportPdf = 'خروجی PDF';
  static const String exportExcel = 'خروجی Excel';
  static const String totalSales = 'جمع فروش';
  static const String totalProfit = 'سود کل';

  // پرینتر
  static const String printerSettings = 'تنظیمات پرینتر';
  static const String bluetoothPrinter = 'پرینتر بلوتوث';
  static const String wifiPrinter = 'پرینتر وای‌فای';
  static const String printerIp = 'آدرس IP پرینتر';
  static const String printerPort = 'پورت';
  static const String scanDevices = 'اسکن دستگاه‌ها';
  static const String connectPrinter = 'اتصال به پرینتر';
  static const String testPrint = 'پرینت تست';
  static const String testConnection = 'تست اتصال';
  static const String printerConnected = 'پرینتر متصل شد';
  static const String printerDisconnected = 'پرینتر قطع شد';
  static const String printerNotFound = 'پرینتر پیدا نشد';

  // سینک
  static const String syncing = 'در حال همگام‌سازی...';
  static const String synced = 'همگام‌سازی شد';
  static const String syncFailed = 'همگام‌سازی ناموفق';
  static const String offline = 'آفلاین';
  static const String online = 'آنلاین';

  // پیام‌های عمومی
  static const String save = 'ذخیره';
  static const String cancel = 'انصراف';
  static const String delete = 'حذف';
  static const String edit = 'ویرایش';
  static const String add = 'افزودن';
  static const String confirm = 'تأیید';
  static const String close = 'بستن';
  static const String search = 'جستجو';
  static const String filter = 'فیلتر';
  static const String all = 'همه';
  static const String yes = 'بله';
  static const String no = 'خیر';
  static const String retry = 'تلاش مجدد';
  static const String loading = 'در حال بارگذاری...';
  static const String noData = 'داده‌ای وجود ندارد';
  static const String error = 'خطا';
  static const String success = 'موفق';
  static const String warning = 'هشدار';
  static const String deleteConfirm = 'آیا از حذف این مورد مطمئن هستید؟';
  static const String operationSuccess = 'عملیات با موفقیت انجام شد';
  static const String operationFailed = 'عملیات ناموفق بود';
  static const String networkError = 'خطا در اتصال به اینترنت';
  static const String serverError = 'خطا در ارتباط با سرور';
  static const String toman = 'تومان';
  static const String count = 'عدد';

  // رسید
  static const String receiptTitle = 'رسید خرید';
  static const String receiptThankYou = 'با تشکر از خرید شما';
  static const String receiptDate = 'تاریخ';
  static const String receiptInvoiceNo = 'شماره فاکتور';
}
