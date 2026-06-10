module MogiFixtures
  def mogi_detail_html
    File.read(Rails.root.join("spec/fixtures/mogi/detail.html"))
  end

  def mogi_list_html
    File.read(Rails.root.join("spec/fixtures/mogi/list.html"))
  end

  # Minimal list page wrapping the given detail URLs as anchors.
  def mogi_list_with(*urls)
    "<html><body>#{urls.map { |u| %(<a href="#{u}">x</a>) }.join}</body></html>"
  end
end

RSpec.configure { |c| c.include MogiFixtures }
