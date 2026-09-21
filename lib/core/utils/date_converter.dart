import 'package:shamsi_date/shamsi_date.dart';

/// ابزار تبدیل تاریخ میلادی به شمسی
/// تمام تاریخ‌های برنامه از این کلاس نمایش داده می‌شوند
class DateConverter {
  DateConverter._();

  // نام ماه‌های فارسی
  static const List<String> _farsiMonths = [
    'فروردین', 'اردیبهشت', 'خرداد',
    'تیر',     'مرداد',    'شهریور',
    'مهر',     'آبان',     'آذر',
    'دی',      'بهمن',     'اسفند',
  ];

  // نام روزهای هفته فارسی (از شنبه)
  static const List<String> _farsiWeekDays = [
    'شنبه', 'یک‌شنبه', 'دوشنبه',
    'سه‌شنبه', 'چهارشنبه', 'پنج‌شنبه', 'جمعه',
  ];

  /// تبدیل به فرمت کوتاه شمسی: ۱۴۰۳/۰۱/۱۵
  static String toShamsi(DateTime date) {
    final j = Jalali.fromDateTime(date);
    final y = _toFarsi(j.year.toString());
    final m = _toFarsi(j.month.toString().padLeft(2, '0'));
    final d = _toFarsi(j.day.toString().padLeft(2, '0'));
    return '$y/$m/$d';
  }

  /// تبدیل به فرمت بلند شمسی: ۱۵ فروردین ۱۴۰۳
  static String toShamsiLong(DateTime date) {
    final j = Jalali.fromDateTime(date);
    final day   = _toFarsi(j.day.toString());
    final month = _farsiMonths[j.month - 1];
    final year  = _toFarsi(j.year.toString());
    return '$day $month $year';
  }

  /// تاریخ و ساعت با هم: ۱۴۰۳/۰۱/۱۵ - ۱۴:۳۰
  static String toShamsiWithTime(DateTime date) {
    final dateStr = toShamsi(date);
    final hour   = _toFarsi(date.hour.toString().padLeft(2, '0'));
    final minute = _toFarsi(date.minute.toString().padLeft(2, '0'));
    return '$dateStr - $hour:$minute';
  }

  /// فقط ساعت و دقیقه: ۱۴:۳۰
  static String toTime(DateTime date) {
    final hour   = _toFarsi(date.hour.toString().padLeft(2, '0'));
    final minute = _toFarsi(date.minute.toString().padLeft(2, '0'));
    return '$hour:$minute';
  }

  /// نام روز هفته شمسی
  static String weekDayName(DateTime date) {
    final j = Jalali.fromDateTime(date);
    return _farsiWeekDays[j.weekDay - 1]; // weekDay از ۱ شروع می‌شود
  }

  /// تاریخ امروز به شمسی
  static String get today => toShamsi(DateTime.now());

  /// تبدیل رشته شمسی به DateTime میلادی
  /// فرمت ورودی: ۱۴۰۳/۰۱/۱۵ یا ۱۴۰۳-۰۱-۱۵
  static DateTime? fromShamsi(String dateStr) {
    try {
      final parts = dateStr.replaceAll('/', '-').split('-');
      if (parts.length != 3) return null;
      final year  = int.parse(toEnglish(parts[0]));
      final month = int.parse(toEnglish(parts[1]));
      final day   = int.parse(toEnglish(parts[2]));
      return Jalali(year, month, day).toDateTime();
    } catch (_) {
      return null;
    }
  }

  /// نمایش زمان نسبی: ۳ ساعت پیش، لحظاتی پیش و...
  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) {
      return 'لحظاتی پیش';
    }
    if (diff.inMinutes < 60) {
      return '${_toFarsi(diff.inMinutes.toString())} دقیقه پیش';
    }
    if (diff.inHours < 24) {
      return '${_toFarsi(diff.inHours.toString())} ساعت پیش';
    }
    if (diff.inDays < 7) {
      return '${_toFarsi(diff.inDays.toString())} روز پیش';
    }
    return toShamsi(date);
  }

  /// تبدیل رقم لاتین به فارسی
  static String _toFarsi(String input) {
    const e = ['0','1','2','3','4','5','6','7','8','9'];
    const f = ['۰','۱','۲','۳','۴','۵','۶','۷','۸','۹'];
    String result = input;
    for (int i = 0; i < e.length; i++) {
      result = result.replaceAll(e[i], f[i]);
    }
    return result;
  }

  /// تبدیل رقم فارسی به لاتین (برای محاسبات)
  static String toEnglish(String input) {
    const f = ['۰','۱','۲','۳','۴','۵','۶','۷','۸','۹'];
    const e = ['0','1','2','3','4','5','6','7','8','9'];
    String result = input;
    for (int i = 0; i < f.length; i++) {
      result = result.replaceAll(f[i], e[i]);
    }
    return result;
  }
}
