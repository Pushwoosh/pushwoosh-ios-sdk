# DocC Documentation Patterns for Pushwoosh SDK

## Правила именования Extension файлов для DocC

DocC для Objective-C требует создания Extension файлов в `.docc/Extensions/` с правильными Swift-стилизованными именами.

## Паттерны именования методов

### 1. Методы БЕЗ параметров (Void methods)

**ВАЖНО:** Методы (functions) и Properties (свойства) документируются по-разному!

**Objective-C сигнатура:**
```objc
- (void)registerForPushNotifications;
- (void)unregisterForPushNotifications;
- (void)startServerCommunication;
- (void)disableReverseProxy;
+ (void)clearNotificationCenter;
```

**Файл:** `registerForPushNotifications.md` (БЕЗ скобок в имени файла)

**Заголовок в файле:**
```markdown
# ``Pushwoosh/registerForPushNotifications()``
```

**✅ ПРАВИЛО:** Методы (functions) всегда СО СКОБКАМИ `()`, даже если параметров нет!

**❌ НЕПРАВИЛЬНО:**
```markdown
# ``Pushwoosh/registerForPushNotifications``  // НЕТ - нужны скобки для методов!
```

---

### 2. Методы с БЕЗЫМЯННЫМИ параметрами

**Objective-C сигнатура:**
```objc
- (void)setTags:(NSDictionary *)tags;
- (void)handlePushRegistration:(NSData *)devToken;
- (void)setEmail:(NSString *)email;
```

**Swift эквивалент:**
```swift
func setTags(_ tags: [AnyHashable: Any])
func handlePushRegistration(_ devToken: Data)
```

**Файл:** `setTags(_:).md` (с `(_:)` в имени)

**Заголовок в файле:**
```markdown
# ``Pushwoosh/setTags(_:)``
```

**❌ НЕПРАВИЛЬНО:**
```markdown
# ``Pushwoosh/setTags:``       // НЕТ - это Objective-C стиль
# ``Pushwoosh/setTags(_)``     // НЕТ - нужно с двоеточием
```

---

### 3. Методы с ИМЕНОВАННЫМИ первым параметром (WithXXX pattern)

**Objective-C сигнатура:**
```objc
- (void)registerForPushNotificationsWith:(NSDictionary *)tags;
- (void)initializeWithAppCode:(NSString *)appCode;
- (void)stopLiveActivityWith:(NSString *)activityId;
```

**Swift эквивалент:**
```swift
func registerForPushNotifications(with tags: [AnyHashable: Any])
func initialize(withAppCode appCode: String)
func stopLiveActivity(with activityId: String)
```

**Файл:** `registerForPushNotifications(with:).md`

**Заголовок в файле:**
```markdown
# ``Pushwoosh/registerForPushNotifications(with:)``
# ``Pushwoosh/initialize(withAppCode:)``
# ``Pushwoosh/stopLiveActivity(with:)``
```

**❌ НЕПРАВИЛЬНО:**
```markdown
# ``Pushwoosh/registerForPushNotificationsWith(_:)``   // НЕТ!
# ``Pushwoosh/stopLiveActivityWith(_:)``               // НЕТ!
```

**Правило:** Если Objective-C метод содержит `With`, `For`, `To` после основного имени - это ИМЕНОВАННЫЙ параметр в Swift!

---

### 4. Методы с completion блоком

**Objective-C сигнатура:**
```objc
- (void)setTags:(NSDictionary *)tags completion:(void(^)(NSError *))completion;
- (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler)completion;
```

**Swift эквивалент:**
```swift
func setTags(_ tags: [AnyHashable: Any], completion: ((Error?) -> Void)?)
func registerForPushNotifications(withCompletion completion: PushwooshRegistrationHandler?)
```

**Файл:**
- `setTags(_:completion:).md`
- `registerForPushNotifications(withCompletion:).md`

**Заголовок в файле:**
```markdown
# ``Pushwoosh/setTags(_:completion:)``
# ``Pushwoosh/registerForPushNotifications(withCompletion:)``
```

**⚠️ ВАЖНО: Методы WithCompletion имеют ДВА варианта имени в Swift!**

Swift иногда сокращает `withCompletion:` до просто `completion:`. Поэтому нужны **ОБА файла**:

1. `registerForPushNotifications(withCompletion:).md` - полное имя
2. `registerForPushNotifications(completion:).md` - сокращенное имя

То же для:
- `unregisterForPushNotifications(withCompletion:)` + `unregisterForPushNotifications(completion:)`
- `stopLiveActivity(withCompletion:)` + `stopLiveActivity(completion:)`

**❌ НЕПРАВИЛЬНО:**
```markdown
# ``Pushwoosh/setTags:completion:``                          // НЕТ!
# ``Pushwoosh/registerForPushNotificationsWithCompletion(_:)`` // НЕТ!
```

---

### 5. Методы с несколькими параметрами

**Objective-C сигнатура:**
```objc
- (void)startLiveActivityWithToken:(NSString *)token activityId:(NSString *)activityId;
- (void)sendPurchase:(NSString *)productId withPrice:(NSDecimalNumber *)price currencyCode:(NSString *)code andDate:(NSDate *)date;
- (void)mergeUserId:(NSString *)oldId to:(NSString *)newId doMerge:(BOOL)merge completion:(void(^)(NSError *))completion;
```

**Swift эквивалент:**
```swift
func startLiveActivity(withToken token: String, activityId: String)
func sendPurchase(_ productId: String, withPrice price: NSDecimalNumber, currencyCode code: String, andDate date: Date)
func mergeUserId(_ oldId: String, to newId: String, doMerge merge: Bool, completion: ((Error?) -> Void)?)
```

**Файл:**
- `startLiveActivity(withToken:activityId:).md`
- `sendPurchase(_:withPrice:currencyCode:andDate:).md`
- `mergeUserId(_:to:doMerge:completion:).md`

**Заголовок в файле:**
```markdown
# ``Pushwoosh/startLiveActivity(withToken:activityId:)``
# ``Pushwoosh/sendPurchase(_:withPrice:currencyCode:andDate:)``
# ``Pushwoosh/mergeUserId(_:to:doMerge:completion:)``
```

**Правило для множественных параметров:**
- Первый параметр БЕЗ имени → `(_:)`
- Первый параметр с предлогом (With/For/To) → `(withToken:)` или `(for:)` и т.д.
- Остальные параметры используют свои label имена

---

### 6. Getters (методы возвращающие значение)

**Objective-C сигнатура:**
```objc
- (NSString *)getPushToken;
- (NSString *)getHWID;
+ (NSString *)version;
```

**Swift эквивалент:**
```swift
func getPushToken() -> String?
func getHWID() -> String
class func version() -> String
```

**Файл:** `getPushToken.md` (БЕЗ скобок в имени файла)

**Заголовок в файле:**
```markdown
# ``Pushwoosh/getPushToken()``
# ``Pushwoosh/getHWID()``
# ``Pushwoosh/version()``
```

**✅ ПРАВИЛО:** Это методы (functions), поэтому СО СКОБКАМИ `()`!

**❌ НЕПРАВИЛЬНО:**
```markdown
# ``Pushwoosh/getPushToken``  // НЕТ - нужны скобки!
```

---

### 7. Методы с особыми именами (ToStart, ToXXX)

**Objective-C сигнатура:**
```objc
- (void)sendPushToStartLiveActivityToken:(NSString *)token;
```

**Swift эквивалент:**
```swift
func sendPushToStartLiveActivity(token: String)
```

**Файл:** `sendPushToStartLiveActivity(token:).md`

**Заголовок в файле:**
```markdown
# ``Pushwoosh/sendPushToStartLiveActivity(token:)``
```

**❌ НЕПРАВИЛЬНО:**
```markdown
# ``Pushwoosh/sendPushToStartLiveActivityToken(_:)``  // НЕТ!
```

**Правило:** Swift удаляет дублирующиеся слова. `sendPushToStartLiveActivityToken:` → `sendPushToStartLiveActivity(token:)`

---

## Алгоритм определения правильного имени

1. **Это Property или Method?**
   - Property (свойство): `@property` → БЕЗ скобок
     - `applicationCode`, `delegate`, `language`
   - Method (функция): `- (type)name` → СО СКОБКАМИ `()`
     - `registerForPushNotifications()`, `getPushToken()`

2. **Метод без параметров?** → Со скобками `()`
   - `registerForPushNotifications()`
   - `disableReverseProxy()`

3. **Первый параметр с предлогом (With/For/To/From)?** → Именованный параметр
   - `initializeWithAppCode:` → `initialize(withAppCode:)`
   - `registerForPushNotificationsWith:` → `registerForPushNotifications(with:)`

4. **Первый параметр сразу после имени метода?** → Безымянный `(_:)`
   - `setTags:` → `setTags(_:)`
   - `handlePushRegistration:` → `handlePushRegistration(_:)`

5. **Метод заканчивается на WithCompletion?** → Именованный параметр
   - `registerForPushNotificationsWithCompletion:` → `registerForPushNotifications(withCompletion:)`

6. **Есть completion блок как второй параметр?** → Добавить `completion:`
   - `setTags:completion:` → `setTags(_:completion:)`

---

## Структура Extension файла

```markdown
# ``Pushwoosh/methodName``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Краткое описание метода (одна строка).

## Discussion

Подробное описание работы метода, примеры использования.

## Parameters

- paramName: Описание параметра

## Returns

Описание возвращаемого значения (если есть)
```

**ВАЖНО:** `mergeBehavior: override` необходим, чтобы DocC не создавал дубликаты символов!

---

## Примеры реальных исправлений

### ❌ БЫЛО (неправильно):
```markdown
Файл: registerForPushNotifications.md
# ``Pushwoosh/registerForPushNotifications``  // Без скобок - НЕПРАВИЛЬНО для методов!
```

### ✅ СТАЛО (правильно):
```markdown
Файл: registerForPushNotifications.md
# ``Pushwoosh/registerForPushNotifications()``  // Со скобками - ПРАВИЛЬНО!
```

### Разница между Methods и Properties:

**Methods (методы/функции) - СО СКОБКАМИ:**
```markdown
# ``Pushwoosh/disableReverseProxy()``
# ``Pushwoosh/registerForPushNotifications()``
# ``Pushwoosh/getPushToken()``
```

**Properties (свойства) - БЕЗ СКОБОК:**
```markdown
# ``Pushwoosh/applicationCode``
# ``Pushwoosh/delegate``
# ``Pushwoosh/language``
```

---

### ❌ БЫЛО (неправильно):
```markdown
Файл: registerForPushNotificationsWith(_:).md
# ``Pushwoosh/registerForPushNotificationsWith(_:)``
```

### ✅ СТАЛО (правильно):
```markdown
Файл: registerForPushNotifications(with:).md
# ``Pushwoosh/registerForPushNotifications(with:)``
```

---

### ❌ БЫЛО (неправильно):
```markdown
Файл: stopLiveActivityWith(_:).md
# ``Pushwoosh/stopLiveActivityWith(_:)``
```

### ✅ СТАЛО (правильно):
```markdown
Файл: stopLiveActivity(with:).md
# ``Pushwoosh/stopLiveActivity(with:)``
```

---

## Проверка правильности

Чтобы проверить правильность имени:

1. Открыть Xcode
2. Build Documentation (⌃⇧⌘D)
3. Проверить, есть ли ошибки типа "Symbol not found"
4. Проверить, отображается ли документация для метода

Или использовать команду:
```bash
xcodebuild docbuild -scheme Pushwoosh -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## Частые ошибки

1. **УБРАНЫ скобки `()` для методов** (самая частая ошибка!)
   - ❌ `registerForPushNotifications` - БЕЗ скобок для method
   - ✅ `registerForPushNotifications()` - СО скобками!
   - ❌ `disableReverseProxy` - БЕЗ скобок для method
   - ✅ `disableReverseProxy()` - СО скобками!

2. **Перепутаны Methods и Properties**
   - Methods (functions): `- (void)name` → СО СКОБКАМИ `()`
   - Properties: `@property` → БЕЗ СКОБОК

3. **Использован Objective-C стиль с двоеточиями**
   - ❌ `setTags:`
   - ✅ `setTags(_:)`

4. **Не преобразованы методы WithXXX**
   - ❌ `initializeWithAppCode(_:)`
   - ✅ `initialize(withAppCode:)`

5. **Неправильные имена для методов ToXXX**
   - ❌ `sendPushToStartLiveActivityToken(_:)`
   - ✅ `sendPushToStartLiveActivity(token:)`

---

## Полезные команды для проверки

Найти все файлы с неправильными паттернами:

```bash
# Найти методы с скобками () (возможно неправильно)
grep -r "()``" Extensions/

# Найти методы With(_:) (должны быть (with:))
grep -r "With(_:)" Extensions/

# Найти методы WithCompletion(_:)
grep -r "WithCompletion(_:)" Extensions/

# Проверить все заголовки
find Extensions -name "*.md" -exec head -1 {} \; | sort
```
