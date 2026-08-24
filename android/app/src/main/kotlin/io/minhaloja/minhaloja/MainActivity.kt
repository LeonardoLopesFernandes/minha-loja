package io.minhaloja.minhaloja

import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "minhaloja/pdf"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "renderPdfToRgba" -> {
                        try {
                            val bytes = call.argument<ByteArray>("bytes")
                            val w = call.argument<Int>("w") ?: 0
                            val h = call.argument<Int>("h") ?: 0
                            if (bytes == null || w <= 0 || h <= 0) {
                                result.error("BAD_ARGS", "bytes/w/h invalid", null)
                                return@setMethodCallHandler
                            }
                            val rgba = renderPdfToRgba(bytes, w, h)
                            if (rgba == null) {
                                result.error("RENDER_FAIL", "null bitmap", null)
                            } else {
                                result.success(rgba)
                            }
                        } catch (e: Exception) {
                            result.error("EXC", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Fiel ao renderPdfToBitmap do MLoja: renderiza a página em sua proporção
    // nativa via PdfRenderer (RENDER_MODE_FOR_PRINT), que NÃO desenha a camada
    // de widget de formulário por cima do conteúdo estático (evitando o texto/
    // preço duplicado que o pdf_render - Pdfium próprio - produz).
    private fun renderPdfToRgba(bytes: ByteArray, targetW: Int, targetH: Int): Map<String, Any>? {
        val file = File(cacheDir, "pdf_render_${System.currentTimeMillis()}.pdf")
        file.outputStream().use { it.write(bytes) }
        val fd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = PdfRenderer(fd)
        try {
            if (renderer.pageCount < 1) return null
            renderer.openPage(0).use { page ->
                val pw = page.width.toDouble()
                val ph = page.height.toDouble()
                val scale = kotlin.math.minOf(
                    kotlin.math.ceil(targetW / pw),
                    kotlin.math.ceil(targetH / ph),
                    8.0
                ).coerceAtLeast(1.0).toInt()
                var rw = (pw * scale).toInt().coerceAtMost(7200)
                val rh = (ph * scale).toInt()
                val bmp = Bitmap.createBitmap(rw, rh, Bitmap.Config.ARGB_8888)
                page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                val pixels = IntArray(rw * rh)
                bmp.getPixels(pixels, 0, rw, 0, 0, rw, rh)
                bmp.recycle()
                val out = ByteArray(rw * rh * 4)
                for (i in pixels.indices) {
                    val p = pixels[i]
                    val o = i * 4
                    out[o] = ((p shr 16) and 0xFF).toByte()
                    out[o + 1] = ((p shr 8) and 0xFF).toByte()
                    out[o + 2] = (p and 0xFF).toByte()
                    out[o + 3] = ((p shr 24) and 0xFF).toByte()
                }
                return mapOf("width" to rw, "height" to rh, "bytes" to out)
            }
        } finally {
            renderer.close()
            fd.close()
            file.delete()
        }
    }
}
