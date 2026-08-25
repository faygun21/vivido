namespace Vivido.Scoring;

using System;

/// <summary>
/// Açık TSP (open travelling salesman problem) çözücüsü — Held-Karp (DP + bitmask).
///
/// Başlangıç noktası SABİTTİR (kullanıcının seçtiği başlangıç), dönüş yoktur.
/// n ≤ 16 için kesin optimum: 2ⁿ·n durum. n=9 (başlangıç + 8 ev) → 4608 durum, &lt;1 ms.
///
/// NEDEN HELD-KARP: "en kısa rota" iddiası sezgisele bırakılamaz
/// (docs/01-PROJE-PLANI.md §7.2). n ≤ 8'de brute-force 40320 permütasyon
/// tararken Held-Karp 4608 duruma iner; üstüne tek bir permütasyonu bile
/// atlamaz — kesin optimum garantisi vardır.
///
/// Vivido.Scoring "saf proje" kuralına uyar: girdi maliyet matrisi, çıktı yol — I/O yok.
/// </summary>
public static class TravelingSalesman
{
    /// <summary>
    /// Bitmask taşmasını önleyen güvenlik sınırı. Ürün sınırı 8 evdir
    /// (controller'da RouteLimits.MaxStops ile doğrulanır); bu yalnızca
    /// DP'nin 2ⁿ·n bellek/işlem patlamasını engelleyen iç korumadır.
    /// </summary>
    public const int MaxNodes = 16;

    public sealed record TspResult(int[] Path, double TotalCost);

    /// <summary>
    /// <paramref name="startIndex"/> sabit başlangıç olacak şekilde en kısa açık rotayı bulur.
    /// <para><c>cost[i,j]</c> = i düğümünden j düğümüne geçiş maliyeti (saniye, metre vb.).
    /// Bağlantısız yollar <see cref="double.PositiveInfinity"/> ile gösterilir.</para>
    /// <para>Dönüş: <c>Path</c> düğüm indeksleri ziyaret sırasıyla (<c>Path[0] = startIndex</c>),
    /// <c>TotalCost</c> toplam maliyet.</para>
    /// </summary>
    public static TspResult SolveFixedStart(double[,] cost, int startIndex)
    {
        if (cost is null) throw new ArgumentNullException(nameof(cost));

        int n = cost.GetLength(0);
        if (n == 0) return new TspResult(Array.Empty<int>(), 0.0);
        if (cost.GetLength(1) != n)
            throw new ArgumentException("Maliyet matrisi kare olmalı (n x n).", nameof(cost));
        if (n > MaxNodes)
            throw new ArgumentException($"n ≤ {MaxNodes} desteklenir (bitmask int sınırı).", nameof(cost));
        if (startIndex < 0 || startIndex >= n)
            throw new ArgumentOutOfRangeException(nameof(startIndex));

        if (n == 1)
            return new TspResult(new[] { startIndex }, 0.0);

        int startBit = 1 << startIndex;
        int totalMasks = 1 << n;
        int full = totalMasks - 1;

        // dp[mask][i] — yalnızca `mask` düğümleri gezilip i'de biten en kısa yol.
        // `mask` HER ZAMAN startBit'i içerir (başlangıç ziyaret edilmiş sayılır).
        var dp = new double[totalMasks, n];
        var parent = new int[totalMasks, n];
        for (int mask = 0; mask < totalMasks; mask++)
        {
            for (int i = 0; i < n; i++)
            {
                dp[mask, i] = double.PositiveInfinity;
                parent[mask, i] = -1;
            }
        }
        dp[startBit, startIndex] = 0.0;

        // Geçişler yalnızca mask'e BİT EKLER (nextMask > mask) — artan mask sırası güvenli.
        for (int mask = startBit; mask <= full; mask++)
        {
            if ((mask & startBit) == 0) continue; // başlangıç düğümü olmayan durumlar geçersiz

            for (int i = 0; i < n; i++)
            {
                if ((mask & (1 << i)) == 0) continue;
                if (double.IsPositiveInfinity(dp[mask, i])) continue;

                for (int j = 0; j < n; j++)
                {
                    if ((mask & (1 << j)) != 0) continue;
                    if (double.IsPositiveInfinity(cost[i, j])) continue;

                    int nextMask = mask | (1 << j);
                    double candidate = dp[mask, i] + cost[i, j];
                    if (candidate < dp[nextMask, j])
                    {
                        dp[nextMask, j] = candidate;
                        parent[nextMask, j] = i;
                    }
                }
            }
        }

        // Açık TSP: son düğüm serbest (başlangıca dönülmüyor). Başlangıçtan farklı,
        // ulaşılabilir en ucuz bitişi seç.
        int end = -1;
        double best = double.PositiveInfinity;
        for (int i = 0; i < n; i++)
        {
            if (i == startIndex) continue;
            if (dp[full, i] < best)
            {
                best = dp[full, i];
                end = i;
            }
        }

        if (end == -1)
            throw new InvalidOperationException(
                "Tüm düğümleri bağlayan bir yol yok — maliyet matrisi kopuk (sonsuz maliyetler).");

        // Yolu geriye doğru kur: end → ... → start.
        var path = new int[n];
        int pos = n - 1;
        int maskIt = full;
        int current = end;
        while (current != -1)
        {
            path[pos--] = current;
            int prev = parent[maskIt, current];
            maskIt &= ~(1 << current);
            current = prev;
        }

        return new TspResult(path, best);
    }
}
