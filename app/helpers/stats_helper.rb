module StatsHelper
  def del(int, pre=0)
    number_with_precision(int, precision: pre, delimiter: ",")
  end

  def humansize(int, pre=0)
    number_to_human_size(int, precision: pre)
  end

  def pct(int, pre=0)
    number_to_percentage(int, precision: pre)
  end

  def percent(id, target, total)
    "document.querySelector('#stats-pct-#{id}').innerText = pct(#{target}, #{total});".html_safe
  end

  def section(title, content, percent_id = nil)
    extra = percent_id.nil? ? "<td></td>" : "<td class='stats-pct' id='stats-pct-#{percent_id}'></td>"
    "<tr>" \
    "<td style='width:250px;'>#{title}</td>" \
    "<td style='width:105px;'>#{content}</td>" \
    "#{extra}" \
    "</tr>".html_safe
  end
end
