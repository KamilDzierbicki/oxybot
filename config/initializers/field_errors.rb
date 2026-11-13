# Invalid fields are marked for screen readers too: aria-invalid plus a link to the form's error summary,
# instead of Rails' default wrapper div that only changes the border color.
ActionView::Base.field_error_proc = proc do |html_tag, _instance|
  if html_tag.match?(/\A<(input|select|textarea)\b/) && !html_tag.match?(/type="hidden"/)
    html_tag.sub(/\A<(input|select|textarea)\b/, '<\1 aria-invalid="true" aria-describedby="form-errors"').html_safe
  else
    html_tag
  end
end
