class PaginatedDecorator < Draper::CollectionDecorator
  delegate :current_page, :total_pages, :is_first_page?, :is_last_page?, :sequential_paginator_mode, :max_numbered_pages, :records, :total_count
end
