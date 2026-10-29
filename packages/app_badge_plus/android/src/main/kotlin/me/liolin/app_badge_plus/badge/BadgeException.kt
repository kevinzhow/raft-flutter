package me.liolin.app_badge_plus.badge

import androidx.annotation.Keep;

@Keep
class BadgeException : Exception {
    constructor(message: String) : super(message)
    constructor(message: String, cause: Throwable) : super(message, cause)
}