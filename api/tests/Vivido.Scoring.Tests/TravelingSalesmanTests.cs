using FluentAssertions;
using Vivido.Scoring;

namespace Vivido.Scoring.Tests;

/// <summary>
/// Held-Karp TSP çözücüsünün doğruluğu — plan dokümanı docs/01-PROJE-PLANI.md §13.3:
/// "TSP doğruluğu | Held-Karp çıktısı, n ≤ 6 için brute force ile karşılaştırılır —
/// birebir aynı olmalı." Burada n ≤ 8'e kadar büyütülüyor ve tek tek örnekler de var.
/// </summary>
public class TravelingSalesmanTests
{
    [Theory]
    [InlineData(2)]
    [InlineData(3)]
    [InlineData(4)]
    [InlineData(5)]
    [InlineData(6)]
    [InlineData(7)]
    [InlineData(8)]
    public void HeldKarp_BruteForceIleAyniMaliyetiBulur(int n)
    {
        // Deterministik üretim — aynı girdi her seferinde aynı sonucu vermeli (I6 ruhu).
        var rng = new Random(42 + n);
        var cost = RandomMatrix(rng, n, asymmetric: true);

        var tsp = TravelingSalesman.SolveFixedStart(cost, startIndex: 0);
        var brute = BruteForce(cost, startIndex: 0);

        tsp.Path.Should().HaveCount(n);
        tsp.Path[0].Should().Be(0); // başlangıç her zaman sabit
        tsp.Path.Should().OnlyHaveUniqueItems();
        tsp.TotalCost.Should().BeApproximately(brute.Cost, 1e-9);
        PathCost(cost, tsp.Path).Should().BeApproximately(brute.Cost, 1e-9);
    }

    [Fact]
    public void UcDugumde_EnKisaRotaBulunur()
    {
        // 0 → 2 → 1 en kısa; 0 → 1 doğrudan pahalı.
        double[,] cost =
        {
            { 0, 100, 10 },
            { 10, 0, 100 },
            { 100, 10, 0 },
        };

        var result = TravelingSalesman.SolveFixedStart(cost, 0);

        result.Path.Should().Equal(0, 2, 1);
        result.TotalCost.Should().Be(20);
    }

    [Fact]
    public void BaslangicHerZamanYolunBasindadir()
    {
        var rng = new Random(7);
        var cost = RandomMatrix(rng, 6, asymmetric: true);

        var result = TravelingSalesman.SolveFixedStart(cost, startIndex: 3);

        result.Path[0].Should().Be(3);
        result.Path.Should().OnlyHaveUniqueItems();
    }

    [Fact]
    public void BaglantisizYol_InfinityAtlanir()
    {
        // 0 → 1 doğrudan imkânsız; 0 → 2 → 1 üzerinden gitmek zorunda.
        double[,] cost =
        {
            { 0, double.PositiveInfinity, 5 },
            { 1, 0, 1 },
            { 5, 1, 0 },
        };

        var result = TravelingSalesman.SolveFixedStart(cost, 0);

        result.Path.Should().Equal(0, 2, 1);
        result.TotalCost.Should().Be(6);
    }

    [Fact]
    public void TekDugum_SadeceBaslangicDondurur()
    {
        var result = TravelingSalesman.SolveFixedStart(new double[,] { { 0 } }, 0);

        result.Path.Should().Equal(0);
        result.TotalCost.Should().Be(0);
    }

    [Fact]
    public void SimetrikMatriste_TersYonAyniMaliyetiVerir()
    {
        // Simetrik mesafe matrisi (metre) — optimal 0→1→2: 10 + 15 = 25.
        double[,] cost =
        {
            { 0, 10, 20 },
            { 10, 0, 15 },
            { 20, 15, 0 },
        };

        var result = TravelingSalesman.SolveFixedStart(cost, 0);

        result.TotalCost.Should().Be(25);
        PathCost(cost, result.Path).Should().Be(25);
    }

    private static double[,] RandomMatrix(Random rng, int n, bool asymmetric)
    {
        var m = new double[n, n];
        for (int i = 0; i < n; i++)
        {
            for (int j = 0; j < n; j++)
            {
                if (i == j) { m[i, j] = 0; continue; }
                // Simetri istenirse m[i,j] = m[j,i]; burada asimetrik (OSRM matrisi asimetrik olabilir).
                m[i, j] = asymmetric ? rng.Next(1, 1000) : 0;
            }
        }
        if (!asymmetric)
        {
            for (int i = 0; i < n; i++)
                for (int j = i + 1; j < n; j++)
                {
                    var v = rng.Next(1, 1000);
                    m[i, j] = v;
                    m[j, i] = v;
                }
        }
        return m;
    }

    private static double PathCost(double[,] cost, int[] path)
    {
        double total = 0;
        for (int i = 0; i < path.Length - 1; i++)
            total += cost[path[i], path[i + 1]];
        return total;
    }

    private static (int[] Path, double Cost) BruteForce(double[,] cost, int startIndex)
    {
        int n = cost.GetLength(0);
        var others = Enumerable.Range(0, n).Where(i => i != startIndex).ToArray();
        double best = double.PositiveInfinity;
        int[] bestPath = Array.Empty<int>();

        foreach (var perm in Permutations(others))
        {
            var path = new[] { startIndex }.Concat(perm).ToArray();
            var c = PathCost(cost, path);
            if (c < best)
            {
                best = c;
                bestPath = path;
            }
        }

        return (bestPath, best);
    }

    private static IEnumerable<int[]> Permutations(int[] items)
    {
        if (items.Length <= 1)
        {
            yield return items;
            yield break;
        }

        for (int i = 0; i < items.Length; i++)
        {
            var rest = items.Where((_, idx) => idx != i).ToArray();
            foreach (var perm in Permutations(rest))
                yield return new[] { items[i] }.Concat(perm).ToArray();
        }
    }
}
