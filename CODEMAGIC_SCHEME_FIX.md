# حل مشكلة "Scheme Runner not found" في Codemagic

## المشكلة
Codemagic يظهر الخطأ:
```
Scheme "Runner" not found from repository! Please reconfigure your project.
```

## السبب
Codemagic يتحقق من scheme **قبل** أن تعمل السكريبتات في `codemagic.yaml`. حتى لو كان الملف موجوداً في Git، Codemagic يحاول اكتشاف iOS project تلقائياً قبل السكريبتات.

## الحلول المطبقة

### ✅ الحل 1: ملف scheme موجود في Git
- الملف موجود في: `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- تم رفعه إلى Git في commit: `105c54c`

### ✅ الحل 2: سكريبت لإنشاء scheme في البداية
- تم إضافة سكريبت في `codemagic.yaml` ينشئ scheme قبل أي عملية أخرى
- السكريبت موجود في: `Setup iOS scheme (CRITICAL - must be first)`

## إعدادات Codemagic المطلوبة

### ⚠️ مهم جداً: تأكد من هذه الإعدادات في Codemagic:

1. **في صفحة Workflow Editor:**
   - ✅ **Use codemagic.yaml**: يجب أن يكون **مفعّل**
   - ❌ لا تستخدم "Automatic iOS detection"
   - ✅ استخدم فقط `codemagic.yaml` للبناء

2. **في إعدادات Build:**
   - ✅ **Build for platforms**: iOS فقط
   - ✅ **Use codemagic.yaml**: مفعّل
   - ❌ لا تفعل "Auto-detect iOS project"

3. **في إعدادات Distribution:**
   - ✅ **Email**: مفعّل
   - Email: `bake16t@gmail.com`

## إذا استمرت المشكلة

### الخطوة 1: تحقق من إعدادات Codemagic
1. اذهب إلى Codemagic → Settings → Workflow Editor
2. تأكد من أن **"Use codemagic.yaml"** مفعّل
3. تأكد من أن **"Automatic iOS detection"** غير مفعّل

### الخطوة 2: تحقق من Branch
تأكد من أنك تبني من branch `main` الذي يحتوي على:
- `codemagic.yaml` المحدث
- `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`

### الخطوة 3: تحقق من الملفات في Git
شغّل هذا الأمر محلياً:
```bash
git ls-files ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
```

يجب أن يظهر:
```
ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
```

### الخطوة 4: إذا لم يعمل
إذا استمرت المشكلة بعد التأكد من كل شيء:
1. اذهب إلى Codemagic → Settings → Workflow Editor
2. اضغط "Switch to YAML configuration"
3. تأكد من أن `codemagic.yaml` هو المستخدم
4. احفظ التغييرات
5. شغّل Build جديد

## الملفات المطلوبة في Git

تأكد من وجود هذه الملفات:
- ✅ `codemagic.yaml`
- ✅ `ios/Runner.xcodeproj/project.pbxproj`
- ✅ `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- ✅ `ios/Podfile`
- ✅ `ios/Runner/Info.plist`
- ✅ `ios/Runner/AppDelegate.swift`

## ملاحظة مهمة

إذا كان Codemagic لا يزال يظهر نفس الخطأ بعد كل هذا:
- قد يكون هناك مشكلة في إعدادات Codemagic في الويب
- تأكد من أنك تستخدم **YAML configuration** وليس **Workflow Editor**
- أو العكس - جرب التبديل بينهما

## التحقق من الملفات

شغّل هذا السكريبت للتحقق:
```powershell
.\check-ios-files.ps1
```

