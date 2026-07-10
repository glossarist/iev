# frozen_string_literal: true

module Iev
  module Reconciler
    # Wraps a reconciled ManagedConcept with its ChangeSet and origin.
    # Value object produced by ConceptMerger, consumed by Pipeline + Report.
    #
    # @attr managed_concept [Glossarist::ManagedConcept]
    # @attr change_set [ChangeSet] field-level diffs detected
    # @attr source [Symbol] :both | :termbase_only | :live_only
    ReconciledConcept = Struct.new(:managed_concept, :change_set, :source,
                                   keyword_init: true)
  end
end
