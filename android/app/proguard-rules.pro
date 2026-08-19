# device_calendar 官方文档要求：release 构建（R8 压缩开启时）必须保留
# 该包的类，否则 retrieveCalendars 等调用会在运行时崩溃。
-keep class com.builttoroam.devicecalendar.** { *; }
