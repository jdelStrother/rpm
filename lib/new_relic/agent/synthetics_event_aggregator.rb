# -*- ruby -*-
# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require 'new_relic/agent/event_aggregator'
require 'new_relic/agent/priority_sampled_buffer'

module NewRelic
  module Agent
    class SyntheticsEventAggregator < EventAggregator
      PRIORITY = 'priority'.freeze

      named :SyntheticsEventAggregator
      capacity_key :'synthetics.events_limit'
      enabled_key :'analytics_events.enabled'
      buffer_class PrioritySampledBuffer

      def record event
        return unless enabled?

        @lock.synchronize do
          @buffer.append event: event, priority: event[0][PRIORITY]
        end
      end

      private

      def after_harvest metadata
        record_dropped_synthetics metadata
      end

      def record_dropped_synthetics metadata
        num_dropped = metadata[:seen] - metadata[:captured]
        return unless num_dropped > 0

        NewRelic::Agent.logger.debug("Synthetics transaction event limit (#{metadata[:capacity]}) reached. Further synthetics events this harvest period dropped.")

        engine = NewRelic::Agent.instance.stats_engine
        engine.tl_record_supportability_metric_count("SyntheticsEventAggregator/synthetics_events_dropped", num_dropped)
      end
    end
  end
end

