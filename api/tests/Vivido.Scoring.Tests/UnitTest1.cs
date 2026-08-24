using FluentAssertions;

namespace Vivido.Scoring.Tests;

public class ScoringEngineTests
{
    [Fact]
    public void CalculateCategoryScore_Returns_100_at_tIdeal()
    {
        var score = Vivido.Scoring.ScoringEngine.CalculateCategoryScore(durationMinutes: 5, tIdeal: 5, tHalf: 15, tCutoff: 30);
        score.Should().BeApproximately(100.0, 0.0001);
    }

    [Fact]
    public void CalculateCategoryScore_Returns_50_at_tHalf()
    {
        var score = Vivido.Scoring.ScoringEngine.CalculateCategoryScore(durationMinutes: 30, tIdeal: 10, tHalf: 30, tCutoff: 60);
        score.Should().BeApproximately(50.0, 0.0001);
    }

    [Fact]
    public void CalculateCategoryScore_Returns_0_at_tCutoff()
    {
        var score = Vivido.Scoring.ScoringEngine.CalculateCategoryScore(durationMinutes: 60, tIdeal: 10, tHalf: 30, tCutoff: 60);
        score.Should().BeApproximately(0.0, 0.0001);
    }

    [Fact]
    public void CalculateCategoryScore_Linear_between_ideal_and_half()
    {
        // tIdeal=10 -> 100, tHalf=30 -> 50. At duration=20 expected 75
        var score = Vivido.Scoring.ScoringEngine.CalculateCategoryScore(durationMinutes: 20, tIdeal: 10, tHalf: 30, tCutoff: 60);
        score.Should().BeApproximately(75.0, 0.0001);
    }

    [Fact]
    public void CalculateCategoryScore_Linear_between_half_and_cutoff()
    {
        // tHalf=30 ->50, tCutoff=60 ->0. At duration=45 expected 25
        var score = Vivido.Scoring.ScoringEngine.CalculateCategoryScore(durationMinutes: 45, tIdeal: 10, tHalf: 30, tCutoff: 60);
        score.Should().BeApproximately(25.0, 0.0001);
    }

    [Fact]
    public void CalculateWeightedScore_ExampleScenario1_matches_expected_66_67()
    {
        // Scenario 1 from the spec:
        // kampus: score=50 weight=1.0
        // metro: score=100 weight=0.5
        var categories = new List<(double score, double weight)>
        {
            (50.0, 1.0),
            (100.0, 0.5)
        };

        var overall = Vivido.Scoring.ScoringEngine.CalculateWeightedScore(categories);
        overall.Should().BeApproximately(66.6666666667, 0.01);
    }

    [Fact]
    public void CalculateWeightedScore_ZeroTotalWeight_returns_0()
    {
        var overall = Vivido.Scoring.ScoringEngine.CalculateWeightedScore(new List<(double score, double weight)>());
        overall.Should().Be(0.0);
    }
}
