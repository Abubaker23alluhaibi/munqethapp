# إعداد Codemagic لحل مشكلة iOS
# Codemagic Setup to Fix iOS Issue

## المشكلة
```
Did not find xcodeproj from /Users/builder/clone/ios
```

## الحل

### الخطوة 1: تأكد من استخدام codemagic.yaml

في Codemagic:
1. افتح إعدادات المشروع (Project Settings)
2. تأكد من أن "Use codemagic.yaml" مفعّل
3. أو اختر workflow "ios-workflow" من codemagic.yaml

### الخطوة 2: إذا كنت تستخدم Workflow Editor

في Workflow Editor:
1. اذهب إلى Scripts
2. أضف script قبل Build iOS:

```bash
# Check and recreate iOS project files
echo "Checking iOS project structure..."
cd $CM_BUILD_DIR
pwd
ls -la ios/ || echo "ios directory not found"

# Check if project.pbxproj exists
if [ ! -f "ios/Runner.xcodeproj/project.pbxproj" ]; then
  echo "⚠️ iOS project.pbxproj missing, recreating iOS files..."
  flutter create --platforms=ios .
  echo "✅ iOS project files recreated"
else
  echo "✅ iOS project.pbxproj exists"
fi

# Verify project structure
if [ -f "ios/Runner.xcodeproj/project.pbxproj" ]; then
  echo "✅ project.pbxproj verified"
  ls -la ios/Runner.xcodeproj/
else
  echo "❌ project.pbxproj still missing after recreation"
  exit 1
fi
```

### الخطوة 3: ترتيب Scripts

يجب أن تكون Scripts بالترتيب التالي:
1. Get Flutter dependencies: `flutter pub get`
2. Check and recreate iOS project files (الكود أعلاه)
3. Install CocoaPods: `cd ios && pod install`
4. Build iOS: `flutter build ios --release --no-codesign`

### ملاحظات مهمة

- تأكد من تحديث البريد الإلكتروني في codemagic.yaml
- تأكد من رفع codemagic.yaml إلى Git
- بعد تحديث codemagic.yaml، ارفع التغييرات: `git add codemagic.yaml && git commit -m "Update Codemagic config" && git push`

