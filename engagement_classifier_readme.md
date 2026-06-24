# Engagement Classifier — How It Works

This document describes our current two-stage machine learning pipeline, which classifies social media posts by engagement sub-type (micro), then labels with associated engagement type (macro). It replaces our previous regex-only (key term matching) approach with a process that combines a first pattern matching approach with a second text embedding + pretrained classification model pass. This classification model was trained on our canonical corporate engagement data (social media posts only) and can be retrained and redeployed at regular intervals as our canonical dataset continues to grow.


## What the pipeline does

Every *new* social media post that we collect is processed in two passes: first, is this post an engagement at all? Second, if it is, what kind of engagement (sub-type) is it?

**Stage 1** answers the first question. It looks at how semantically similar the post is to known engagement posts versus known non-engagement posts, and outputs a probability between 0 and 1. If that probability is below a set threshold (which can be tweaked without re-training the model), the post is labeled "Not an Engagement" and the pipeline stops. If it's above the threshold, the post is sent to Stage 2 for classification.

**Stage 2** answers the second question. It takes each post that passed Stage 1 and assigns it one of ten engagement sub-types: Recognition Statement, Community Outreach Event, Sharing Stories, Employee Event, Corporate Recognition, Donation/Grant, Advocacy/Lobbying, Company Operations, Product Line, Sponsorship, or Corporate Issues Report. Stage 2 also outputs a confidence score. If that confidence is below a set threshold (which can be tweaked without re-training the model), the post falls back to "Not an Engagement" even though Stage 1 passed it — a precision safety net.

Both stages use the same set of features to make their decisions. Those features fall into two categories. The first is **embedding similarity**: each post's text is converted into a 768-number fingerprint by Google's text-embedding-005 model, and the pipeline measures how close that fingerprint is to the average fingerprint of each engagement class (computed from analyst-labeled training data). The second is **regex pattern flags**: a curated set of 67 regular expressions checks whether the post contains vocabulary associated with each engagement class, and the results are passed to the models as binary signals.

The trained models learned how to weigh these two types of evidence against each other. The embedding similarities provide continuous semantic signal across all posts; the regex flags provide high-confidence discrete signals at critical decision boundaries. Feature importance analysis showed that embeddings do most of the heavy lifting (93% of decision splits), while regex flags fire rarely but with roughly 4× higher impact per use — acting as tiebreakers when the embeddings alone are ambiguous.

After Stage 2 assigns a sub-type, the pipeline looks up the corresponding engagement type (External Initiative, Internal Initiative, or Acknowledgment) from the regex reference table.

This pipeline **does not classify backlash**. The rate of backlash returned by processing social media posts (which come directly from companies themselves) is negligible.


## How to tune it

Two thresholds control the recall/precision trade-off. Both live at the top of the dbt model file as Jinja variables. Changing them requires only a dbt run — no retraining.

**Gate threshold** (currently 0.25) controls Stage 1's pass/fail boundary. Lowering it lets more posts through to Stage 2, increasing the chance you catch real engagements but also increasing the number of non-engagements that leak into the review queue. Raising it makes the filter stricter, reducing noise but missing more real engagements. Tested ranges: 0.10 gives roughly 97% engagement recall with heavy noise; 0.50 gives roughly 92% recall with moderate noise.

**Stage 2 confidence threshold** (currently 0.50) controls the precision safety net. When Stage 2 is uncertain about its classification, this threshold decides whether to label the post as the uncertain prediction or fall it back to "Not an Engagement." Raising it reduces false positives but drops some real engagements. Lowering it lets more uncertain predictions through for analyst review. Tested ranges: 0.30 gives 97% engagement reclamation with a queue precision of 15%; 0.50 gives 87% reclamation with 18% queue precision.

These two knobs are designed to be adjusted together. A practical workflow is to change one threshold, rerun only Phase 9 of the evaluation pipeline (seconds, no cost), and inspect the confusion matrix until you find an operating point that matches your analyst team's review capacity.


## Where the money goes

There are two cost centers: embedding generation and model prediction. Everything else (regex matching, similarity computation, threshold logic) runs on standard BigQuery compute with no API charges.

**Embedding generation** is the primary cost. Each post's text is sent to the text-embedding-005 API, which charges approximately $0.00002 per 1,000 characters. For a full backfill of roughly 36,000 records averaging 500 characters each, this costs about $0.60. For incremental daily runs processing 50–200 new records, the cost is effectively zero — a fraction of a cent per run.

**Model prediction** (ML.PREDICT on the two boosted tree classifiers) runs inside BigQuery and is billed as standard BigQuery ML compute. For the volumes involved, this is negligible — well under a dollar per month.

To keep costs low, the dbt model uses incremental materialization. After the initial backfill, each subsequent run only embeds and predicts records that don't already exist in the output table. If you need to reprocess everything (after retraining or threshold changes), run a full refresh, which re-embeds the entire table at the one-time backfill cost.

The class centroids table and the two trained models are static assets that persist in BigQuery at no ongoing cost. They only need to be regenerated when you retrain.


## How to improve it over time

**Collect more labels for weak classes.** Product Line, Sponsorship, and Advocacy/Lobbying each have fewer than 200 labeled examples in the full dataset. The model struggles to learn their patterns and often routes them to a neighboring class. Even 50–100 additional analyst-labeled examples per class would meaningfully improve recall. Priority: Product Line (currently near-zero recall), then Sponsorship, then Advocacy/Lobbying.

**Retrain periodically.** As analysts correct predictions and the labeled dataset grows, retrain both stages using the evaluation pipeline you built during development. The training queries take about 10 minutes to run and cost nothing beyond standard compute. A quarterly cadence is reasonable; monthly if the analyst team is generating high volumes of corrections.

**Update the regex reference table.** The 67 regex patterns in the v5 reference table act as high-precision features for the model. When you notice recurring misclassifications that share a distinctive keyword, adding a pattern for it gives the model a strong signal to learn from on the next retrain. Focus on Tier 1 patterns (unambiguous signals) — the feature importance data showed these have the highest per-use impact.

**Recompute class centroids after retraining.** The centroids represent the semantic center of each engagement class as of the training data snapshot. After retraining on new data, regenerate them so they reflect the current distribution of labeled examples. This is a single SQL query that takes seconds.

**Upgrade the embedding model.** The pipeline uses text-embedding-005, the cheapest option. Switching to a higher-quality model (such as gemini-embedding-001 at roughly 7× the per-character cost) would improve the semantic similarity features without any other changes to the pipeline. Worth testing if you've exhausted the other improvement paths and are willing to spend a few dollars more per backfill.

**Experiment with multi-centroid representations.** The current approach computes one centroid per class. Classes like Community Outreach Event contain semantically diverse posts (volunteer events, donation drives, environmental cleanups, youth mentorship) that don't all cluster together. Computing 3–5 sub-centroids per class via k-means and using the maximum similarity across sub-centroids as the feature would better capture this intra-class variation.
