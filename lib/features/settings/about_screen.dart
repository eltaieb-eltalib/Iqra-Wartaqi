import 'package:flutter/material.dart';

/// معلومات التطبيق والمصادر والحقوق — إسناد إلزامي لتنزيل وmp3quran.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حول التطبيق والمصادر')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('اِقْرَأْ وَارْتَقِ – القرآن الكريم للحفظ والمراجعة',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('الإصدار ١.٢.٠', style: TextStyle(fontSize: 16)),
          SizedBox(height: 16),
          Text('نص القرآن الكريم',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          Text(
            'النص بالرسم العثماني من مشروع تنزيل (Tanzil) — نص عثماني ١.١، '
            'بترخيص المشاع الإبداعي CC BY 3.0، ويُستخدم حرفيًا دون أي تعديل '
            'عدا إزالة علامة BOM في مطلع الفاتحة وهي أثر ملفي لا جزء من النص. '
            'المصدر: https://tanzil.net — تم التحقق من عدد الآيات في كل سورة '
            'مقابل بيانات تنزيل الوصفية (quran-data.xml) دون أي اختلاف.',
            style: TextStyle(fontSize: 16, height: 1.7),
          ),
          SizedBox(height: 16),
          Text('التلاوة الصوتية',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          Text(
            'تلاوة الشيخ الزين محمد أحمد (حفص عن عاصم — مرتل) من موقع '
            'mp3quran.net عبر واجهته الرسمية. تنبيه الحقوق: لم ينشر الموقع '
            'ترخيصًا صريحًا بإعادة توزيع التسجيلات؛ لذلك لا يتضمن التطبيق أي '
            'ملفات صوتية مضمّنة: التلاوة تُبث من خوادم المصدر، والتنزيل دون '
            'اتصال يحدث فقط بطلب المستخدم داخل جهازه. يُنصح بأن يبقى التطبيق '
            'مجانيًا غير تجاري إلى حين الحصول على إذن كتابي بإعادة التوزيع.',
            style: TextStyle(fontSize: 16, height: 1.7),
          ),
          SizedBox(height: 16),
          Text('توقيتات الآيات',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          Text(
            'توقيتات بداية ونهاية كل آية من واجهة mp3quran (ayat_timing)، '
            'وهي ما يتيح تكرار كل آية بدقة وتمييز الآية الجارية أثناء التلاوة. '
            'تم التحقق من أن عدد التوقيتات في كل سورة يساوي عدد آياتها.',
            style: TextStyle(fontSize: 16, height: 1.7),
          ),
          SizedBox(height: 16),
          Text('الخطوط',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          Text(
            'خط أميري للقرآن (Amiri Quran) وخط IBM Plex Sans Arabic للواجهة، '
            'وكلاهما بترخيص SIL Open Font License 1.1.',
            style: TextStyle(fontSize: 16, height: 1.7),
          ),
        ],
      ),
    );
  }
}
