import type { ViSemanticComparisonModel } from './viSemanticModel';
import type { ViSemanticPrReview } from './viSemanticPrReview';

/**
 * No-substantive-change detection for a VI semantic PR review (VHS-REQ-661).
 *
 * User story: a PR touching many VIs (e.g. 10) flags every VI as changed in Git
 * even when one of them has no real changes — for example a VI re-saved
 * (recompiled/re-serialized) with different bytes but an identical front panel
 * and block diagram. Reviewers cannot otherwise tell which "changed" VIs are
 * false positives without opening each comparison.
 *
 * Signal (proven by the empty-VI swap experiment): NI's comparison report always
 * renders the "Front Panel Overview" / "Block Diagram Overview" snapshot
 * captions whenever a comparison runs, so `hasDifferences` is `true` even for a
 * semantically identical pair. The reliable no-change signal is therefore zero
 * *itemized* differences across all detail sections — `totals.detailItemCount
 * === 0` on a completed comparison. Attribute-only changes render as detail
 * items, so they are correctly NOT flagged.
 *
 * Pure and dependency-free (type-only imports); no runtime, no new schema.
 */

/**
 * Whether a completed comparison model shows no substantive semantic change: the
 * comparison reported a difference at the overview level (`hasDifferences`,
 * driven by the always-present snapshot captions) but found no itemized
 * differences in any detail section. This is the false-positive case a reviewer
 * wants to discount — Git marked the file changed, LabVIEW found no real
 * difference. A model with `hasDifferences === false` is a genuine no-difference
 * result, not a false positive, so it is not flagged.
 */
export function viHasNoSubstantiveChanges(model: ViSemanticComparisonModel): boolean {
  return model.hasDifferences === true && model.totals.detailItemCount === 0;
}

/** A VI flagged as having no substantive changes despite appearing changed. */
export interface NoSubstantiveChangeVi {
  relativePath: string;
}

/**
 * Detects, over a completed PR review, the VIs whose comparison completed but
 * produced no substantive semantic change. Only `completed` entries are
 * considered — a blocked/failed VI is not a no-change signal, it is an unknown.
 * Deterministic: preserves the review's entry order.
 */
export function detectNoSubstantiveChangeVis(
  review: ViSemanticPrReview
): NoSubstantiveChangeVi[] {
  const flagged: NoSubstantiveChangeVi[] = [];
  for (const entry of review.entries) {
    if (entry.status === 'completed' && viHasNoSubstantiveChanges(entry.model)) {
      flagged.push({ relativePath: entry.relativePath });
    }
  }
  return flagged;
}
