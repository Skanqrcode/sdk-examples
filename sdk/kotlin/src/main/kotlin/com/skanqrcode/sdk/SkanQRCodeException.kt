package com.skanqrcode.sdk

class SkanQRCodeException(
    val code: String,
    message: String,
    val requestId: String?,
    val httpStatus: Int,
) : Exception("$code ($httpStatus): $message")
