# frozen_string_literal: true
# OVERRIDE Hyrax -- Sipity.Entity() eagerly builds debug strings via #inspect even when the debug level is disabled; switched to Logger's block form (only evaluated when enabled).
module SipityDecorator
  def Entity(input, &block) # rubocop:disable Naming/MethodName, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    Hyrax.logger.debug { "Trying to make an Entity for #{input.inspect}" }

    result = case input
             when Sipity::Entity
               input
             when URI::GID, GlobalID
               Hyrax.logger.debug { "Entity() got a GID, searching by proxy" }
               Sipity::Entity.find_by(proxy_for_global_id: input.to_s)
             when SolrDocument
               Hyrax.logger.debug { "Entity() got a SolrDocument, retrying on #{input.to_model}" }
               Entity(input.to_model)
             when Draper::Decorator
               Hyrax.logger.debug { "Entity() got a Decorator, retrying on #{input.model}" }
               Entity(input.model)
             when Sipity::Comment
               Hyrax.logger.debug { "Entity() got a Comment, retrying on #{input.entity}" }
               Entity(input.entity)
             when Valkyrie::Resource
               Hyrax.logger.debug { "Entity() got a Resource, retrying on #{Hyrax::GlobalID(input)}" }
               Entity(Hyrax::GlobalID(input))
             else
               Hyrax.logger.debug { "Entity() got something else, testing #to_global_id" }
               Entity(input.to_global_id) if input.respond_to?(:to_global_id)
             end

    Hyrax.logger.debug { "Entity(): attempting conversion on #{result}" }
    handle_conversion(input, result, :to_sipity_entity, &block)
  rescue URI::GID::MissingModelIdError
    Entity(nil)
  end
  public :Entity
end

Sipity.singleton_class.prepend(SipityDecorator)
