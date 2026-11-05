"""
Trains a small logistic-regression pairwise ranking model that learns to
predict which of two candidate routes a traveler would prefer, given each
route's (duration, cost, CO2, transfer count) - so the Flutter app can rank
its own already-fetched options (from HERE / OSM / the mock generator) by a
*learned* notion of "best", instead of just displaying whatever order the
API happened to return them in.

Why synthetic data: this is a brand-new student app with no real usage logs
yet (no historical record of which route real users actually picked out of
several offered alternatives) - there is nothing else to train on right now.
Synthetic bootstrap data is the standard approach for a new recommender
system before real interaction data exists (e.g. cold-start problem). The
underlying per-mode speed/cost/CO2 assumptions below are copied verbatim
from `lib/data/transport_repository.dart` so the synthetic world matches the
app's own offline generator instead of being an arbitrary invented scenario.
Once the app is actually used, replacing this synthetic set with real
"which option did the user tap" logs and re-running this same script is a
drop-in upgrade path - the training/deployment mechanism doesn't change.

Model: pairwise logistic regression (a standard, simple learning-to-rank
setup - closely related to the Bradley-Terry model). For a pair of routes
(A, B), the input is the *difference* of their normalised "badness"
features (duration/cost/CO2/transfers, each 0=best..1=worst within that
search's candidate set) and the label is 1 if a simulated traveler preferred
A over B. Reduces cleanly to a single linear score per route at inference
time (score = w . features; higher = more recommended) - cheap enough to
run as plain arithmetic in Dart with no ML runtime/dependency needed on
the app side at all.
"""

import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score

rng = np.random.default_rng(42)

# --- Per-mode assumptions, copied from transport_repository.dart ---------
MODES = {
    #           speed_kmh, cost_per_km, co2_per_km, transfers_added
    "train":  (45.0, 0.12, 0.020, 1),
    "mrt":    (33.0, 0.16, 0.018, 0),
    "bus":    (55.0, 0.10, 0.055, 0),
    "ferry":  (24.0, 0.25, 0.045, 1),
    "walk":   (4.5,  0.0,  0.0,   0),
    "taxi":   (38.0, 1.35, 0.150, 0),
    "bike":   (15.0, 0.15, 0.0,   0),
    "other":  (30.0, 0.15, 0.05,  1),
}
MODE_NAMES = list(MODES.keys())


def make_candidate(distance_km, mode_name):
    speed, cost_km, co2_km, base_transfers = MODES[mode_name]
    duration_min = (distance_km / speed) * 60.0
    # A little realistic noise/overhead - waiting for a vehicle, walking to
    # a stop, etc - so it's not a perfectly deterministic formula.
    duration_min += rng.uniform(2, 15)
    cost = cost_km * distance_km + (1.0 if mode_name != "walk" else 0.0)
    co2 = co2_km * distance_km
    transfers = base_transfers + (1 if rng.random() < 0.3 else 0)
    return np.array([duration_min, cost, co2, transfers], dtype=float)


def normalise(features_matrix):
    """Min-max normalise each column to 0..1 within one search's candidate
    set - what matters is how an option compares to the *other alternatives
    offered for this exact search*, not its absolute duration/cost/CO2
    (a 3km trip and a 30km trip have totally different absolute scales)."""
    lo = features_matrix.min(axis=0)
    hi = features_matrix.max(axis=0)
    span = np.where(hi - lo < 1e-9, 1.0, hi - lo)
    return (features_matrix - lo) / span


def simulate_search():
    """One synthetic search: a random trip distance, 2-5 candidate routes
    using different mode combinations, a random simulated traveler
    "persona" (their own weighting of time vs cost vs CO2 vs transfers),
    and which candidate that persona ends up preferring (with some
    decision noise - real people aren't perfectly rational optimizers)."""
    distance_km = rng.uniform(1.5, 35.0)
    n_candidates = rng.integers(2, 6)
    chosen_modes = rng.choice(MODE_NAMES, size=n_candidates, replace=True)
    raw = np.stack([make_candidate(distance_km, m) for m in chosen_modes])
    x = normalise(raw)

    # Persona weights: how much this simulated traveler dislikes each
    # "badness" feature. Dirichlet gives weights that sum to 1 but still
    # vary a lot per persona (some care almost only about speed, some
    # almost only about cost, etc). Alpha is skewed slightly toward CO2
    # since this is a *green* travel app's target user base leans a bit
    # more eco-conscious on average - but still highly diverse, not a
    # single fixed formula.
    weights = rng.dirichlet(alpha=[2.0, 1.5, 2.5, 1.0])
    utility = -(x @ weights) + rng.normal(0, 0.08, size=n_candidates)
    return x, utility


def build_pairwise_dataset(n_searches):
    X_diffs, y = [], []
    for _ in range(n_searches):
        x, utility = simulate_search()
        n = len(utility)
        for i in range(n):
            for j in range(n):
                if i == j:
                    continue
                X_diffs.append(x[i] - x[j])
                y.append(1 if utility[i] > utility[j] else 0)
    return np.array(X_diffs), np.array(y)


X_train, y_train = build_pairwise_dataset(3000)
X_test, y_test = build_pairwise_dataset(800)

model = LogisticRegression(fit_intercept=True, max_iter=1000)
model.fit(X_train, y_train)

train_acc = accuracy_score(y_train, model.predict(X_train))
test_acc = accuracy_score(y_test, model.predict(X_test))

print("Feature order: [duration_norm, cost_norm, co2_norm, transfers_norm]")
print("Learned coefficients:", model.coef_[0])
print("Learned intercept:", model.intercept_[0])
print(f"Train accuracy: {train_acc:.4f}")
print(f"Test accuracy:  {test_acc:.4f}")
