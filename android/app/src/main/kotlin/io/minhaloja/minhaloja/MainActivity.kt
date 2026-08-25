package io.minhaloja.minhaloja

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.ceil
import kotlin.math.min
import kotlin.math.roundToInt

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
                    "composePage" -> {
                        try {
                            @Suppress("UNCHECKED_CAST")
                            val cellsRaw = call.argument<List<Any>>("cells")
                            val cells = cellsRaw?.mapNotNull { it as? ByteArray } ?: emptyList()
                            val cols = call.argument<Int>("cols") ?: 1
                            val rows = call.argument<Int>("rows") ?: 1
                            val overlayName = call.argument<String>("overlay")
                            val semOverlay = call.argument<Boolean>("semOverlay") ?: false
                            val modoVenc = call.argument<Boolean>("vencimentos") ?: false
                            val comums = call.argument<List<Int>>("comums") ?: emptyList()
                            val topFracs = call.argument<List<Double>>("topFracs") ?: emptyList()
                            val validades = call.argument<List<String>>("validades") ?: emptyList()
                            val shiftVenc = (call.argument<Double>("shiftVenc") ?: 0.015).toFloat()
                            val shiftMulti = (call.argument<Double>("shiftMulti") ?: 0.03).toFloat()
                            if (cells.isEmpty() || cols <= 0 || rows <= 0) {
                                result.error("BAD_ARGS", "cells/cols/rows invalid", null)
                                return@setMethodCallHandler
                            }
                            val page = composePage(
                                cells, cols, rows, overlayName, semOverlay, modoVenc,
                                comums, topFracs, validades, shiftVenc, shiftMulti
                            )
                            val stream = ByteArrayOutputStream()
                            page.compress(Bitmap.CompressFormat.PNG, 100, stream)
                            val out = mapOf(
                                "width" to page.width,
                                "height" to page.height,
                                "bytes" to stream.toByteArray()
                            )
                            page.recycle()
                            result.success(out)
                        } catch (e: Exception) {
                            result.error("EXC", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun assetBytes(name: String): ByteArray? = try {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(name)
        assets.open(key).use { it.readBytes() }
    } catch (_: Exception) {
        null
    }

    /** Lê apenas as dimensões de um PNG sem decodificar tudo. */
    private fun pngSize(bytes: ByteArray): Pair<Int, Int> {
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
        return Pair(opts.outWidth, opts.outHeight)
    }

    /**
     * Compõe a página inteira nativamente (igual ao gerarPreviewMulti/
     * gerarPreviewVencimentos do MLoja): fundo branco ou overlay escalado,
     * células com removerBrancoSuave + centralizarConteudo e, no Vencimentos,
     * os textos de validade/rodapé desenhados por cima, centrados na célula.
     */
    private fun composePage(
        cells: List<ByteArray>,
        cols: Int,
        rows: Int,
        overlayName: String?,
        semOverlay: Boolean,
        modoVenc: Boolean,
        comums: List<Int>,
        topFracs: List<Double>,
        validades: List<String>,
        shiftVenc: Float,
        shiftMulti: Float
    ): Bitmap {
        val (cw0, ch0) = pngSize(cells[0])
        val cellW = if (cw0 > 0) cw0 else 800
        val cellH = if (ch0 > 0) ch0 else 1000
        val ovW = cellW * cols
        val ovH = cellH * rows

        val page = Bitmap.createBitmap(ovW, ovH, Bitmap.Config.ARGB_8888)
        val cv = Canvas(page)
        cv.drawColor(Color.WHITE)

        var overlay: Bitmap? = null
        if (!semOverlay && overlayName != null) {
            val ob = assetBytes(overlayName)
            if (ob != null) overlay = BitmapFactory.decodeByteArray(ob, 0, ob.size)
        }
        if (overlay != null) {
            cv.drawBitmap(overlay, null, RectF(0f, 0f, ovW.toFloat(), ovH.toFloat()), null)
        }

        val whitePaint = Paint().apply { color = Color.WHITE }

        for (i in cells.indices) {
            val data = cells[i]
            if (data.isEmpty()) continue
            val bmp = BitmapFactory.decodeByteArray(data, 0, data.size) ?: continue
            removerBrancoSuave(bmp)

            val left = (i % cols) * cellW.toFloat()
            val top = (i / cols) * cellH.toFloat()
            val comum = comums.getOrNull(i) == 1

            if (comum && overlay != null && !semOverlay) {
                cv.drawRect(left, top, left + cellW, top + cellH, whitePaint)
            }
            val maxShift = if (modoVenc && !comum) 0.35f else 1f
            val ignorar = if (comum) 0.03f else 0f
            val shiftY = if (comum) 0f else (if (modoVenc) shiftVenc else shiftMulti)
            centralizarConteudo(cv, bmp, cellW.toFloat(), cellH.toFloat(), left, top, maxShift, ignorar, shiftY)

            val vd = validades.getOrNull(i)?.trim() ?: ""
            if (modoVenc && vd.isNotEmpty()) {
                val tf = (topFracs.getOrNull(i) ?: 0.25).toFloat()
                desenharTextosVenc(cv, left, top, cellW.toFloat(), cellH.toFloat(), vd, tf)
            }
            bmp.recycle()
        }
        overlay?.recycle()
        return page
    }

    /** Igual ao centralizarConteudo do MLoja: estica na célula, só dx. */
    private fun centralizarConteudo(
        canvas: Canvas, bmp: Bitmap, cellW: Float, cellH: Float,
        left: Float, top: Float, maxShiftFrac: Float,
        ignorarBordasFrac: Float, shiftYFrac: Float
    ) {
        try {
            val w = bmp.width; val h = bmp.height
            val targetW = min(w, 800)
            val targetH = ((h * (targetW.toFloat() / w)).toInt()).coerceAtLeast(1)
            val small = if (targetW < w) Bitmap.createScaledBitmap(bmp, targetW, targetH, true) else bmp
            val sw = small.width; val sh = small.height
            val bx0 = (sw * ignorarBordasFrac).toInt()
            val bx1 = (sw * (1f - ignorarBordasFrac)).toInt()
            val by0 = (sh * ignorarBordasFrac).toInt()
            val by1 = (sh * (1f - ignorarBordasFrac)).toInt()
            var minX = sw; var maxX = -1
            var y = by0
            while (y < by1) {
                var x = bx0
                while (x < bx1) {
                    val p = small.getPixel(x, y)
                    if ((p ushr 24 and 0xFF) > 8) {
                        val r = p shr 16 and 0xFF; val g = p shr 8 and 0xFF; val b = p and 0xFF
                        if (r < 250 || g < 250 || b < 250) {
                            if (x < minX) minX = x
                            if (x > maxX) maxX = x
                        }
                    }
                    x += 2
                }
                y += 2
            }
            val dstTop = top - cellH * shiftYFrac
            if (maxX <= minX) {
                canvas.drawBitmap(bmp, null, RectF(left, dstTop, left + cellW, dstTop + cellH), null)
                if (small !== bmp) small.recycle()
                return
            }
            val scaleX = cellW / sw
            val contentDrawW = (maxX - minX + 1) * scaleX
            val dx = (((cellW - contentDrawW) / 2f) - minX * scaleX)
                .coerceIn(-cellW * maxShiftFrac, cellW * maxShiftFrac)
            canvas.drawBitmap(bmp, null, RectF(left + dx, dstTop, left + dx + cellW, dstTop + cellH), null)
            if (small !== bmp) small.recycle()
        } catch (_: Exception) {
            canvas.drawBitmap(
                bmp, null,
                RectF(left, top - cellH * shiftYFrac, left + cellW, top + cellH - cellH * shiftYFrac),
                null
            )
        }
    }

    /** Torna o branco suave transparente (removeBrancoSuave do MLoja). */
    private fun removerBrancoSuave(src: Bitmap) {
        val w = src.width; val h = src.height
        val px = IntArray(w * h)
        src.getPixels(px, 0, w, 0, 0, w, h)
        for (i in px.indices) {
            val p = px[i]
            val a = p ushr 24 and 0xFF
            if (a < 200) continue
            val r = p shr 16 and 0xFF; val g = p shr 8 and 0xFF; val b = p and 0xFF
            val minRGB = min(r, min(g, b))
            if (minRGB >= 200) {
                val t = ((minRGB - 200) / 55f).coerceIn(0f, 1f)
                val newA = ((a * (1 - t * 0.95f)).roundToInt()).coerceIn(0, 255)
                px[i] = if (newA < 4) (p and 0x00FFFFFF) else (newA shl 24) or (p and 0x00FFFFFF)
            }
        }
        src.setPixels(px, 0, w, 0, 0, w, h)
    }

    /** VAL.: <data> + rodapé, vermelho negrito, centrados na célula. */
    private fun desenharTextosVenc(
        canvas: Canvas, left: Float, top: Float, cellW: Float,
        cellH: Float, validade: String, topFrac: Float
    ) {
        val txt = if (validade.length == 8) {
            "${validade.substring(0, 2)}/${validade.substring(2, 4)}/${validade.substring(4)}"
        } else validade

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#D32F2F")
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }

        fun draw(s: String, cy: Float, sizePx: Float) {
            paint.textSize = sizePx
            val fm = paint.fontMetrics
            val baseline = cy - (fm.ascent + fm.descent) / 2f
            canvas.drawText(s, left + cellW / 2f, baseline, paint)
        }

        draw("VAL.: ${txt.uppercase()}", top + cellH * topFrac, cellW / 18f)
        draw("PRÓXIMO DA VALIDADE. CONSUMO RÁPIDO", top + cellH * 0.88f, (cellW / 32f).coerceIn(8f, 26f))
    }

    // Fiel ao renderPdfToBitmap do MLoja: renderiza a página em sua proporção
    // nativa via PdfRenderer (RENDER_MODE_FOR_PRINT).
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
                val s1 = ceil(targetW / pw)
                val s2 = ceil(targetH / ph)
                var scaleD = if (s1 < s2) s1 else s2
                if (scaleD > 8.0) scaleD = 8.0
                if (scaleD < 1.0) scaleD = 1.0
                val sInt = scaleD.toInt()
                val rw = (pw * sInt).toInt().coerceAtMost(7200)
                val rh = (ph * rw / pw).toInt()
                val bmp = Bitmap.createBitmap(rw, rh, Bitmap.Config.ARGB_8888)
                page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                val stream = ByteArrayOutputStream()
                bmp.compress(Bitmap.CompressFormat.PNG, 100, stream)
                bmp.recycle()
                return mapOf("width" to rw, "height" to rh, "bytes" to stream.toByteArray())
            }
        } finally {
            renderer.close()
            fd.close()
            file.delete()
        }
    }
}
