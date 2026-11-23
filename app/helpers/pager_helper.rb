# Page numbers for shared/_pager: [1, :gap, 5, 6, 7, :gap, 41]. Always shows the
# first and last page and keeps the current one near the middle.
module PagerHelper
  def pager_series(page, pages, slots: 7)
    return (1..pages).to_a if pages <= slots

    start = (page - (slots - 1) / 2).clamp(1, pages - slots + 1)
    series = (start...(start + slots)).to_a
    series[1] = :gap if series[0] != 1 && series[1] != 2
    series[0] = 1
    series[-2] = :gap if series[-1] != pages && series[-2] != pages - 1
    series[-1] = pages
    series
  end
end
