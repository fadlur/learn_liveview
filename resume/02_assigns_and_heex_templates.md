## Assign and HEEx templates

Semua data di LiveView disimpan di socket, yang mana adalah sebuah server side struct dengan nama `Phoenix.LiveView.Socket`. Datamu sendiri disimpan di bawah key `assigns` dari struct itu sendiri. Server data tidak pernah berbagi dengan client di luar apa yang templatemu render.

Phoenix template language dinamakan HEEx (HTML+EEx). EEx adalah Embedded Elixir,sebuah elixir string template engine. Template itu bisa file dengan extensi `.heex` atau mereka dibuat secara langsung via `~H` sigil. Kamu dapat belajar lebih lanjut tentang sintaks HEEx di [~H sigil](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#sigil_H/2).

`Phoenix.Component.assign/2` dan `Phoenix.Component.assign/3` membantu menyimpan nilai-nilai itu. Nilai-nilai itu dapat diakses di LiveView via `socket.assigns.name` tapi mereka dapat diakses di dalam HEEx template sebagai `@name`.

Di bagian ini, kita akan membahas bagaimana LiveView meminimalkan muatan melalui kabel dengan memahami interaksi antara assigns dan template.

**Change tracking**
Ketika pertama kali render sebuah `.heex` template, LiveView akan mengirim semua bagian statis dan dinamis dari template ke client. Bayangkan template ini:

```elixir
<h1><%= expand_title(@title) %></h1>
```

template itu memiliki 2 bagian statis, `<h1>` dan `</h1>` dan satu bagian dinamis yang terbuat dari `expand_title(@title)`. Rendering selanjutnya tidak mengirim lagi bagian statis dan hanya mengirim ulang bagian dinamis jika ada perubahan.

Tracking of change dilakukan via assigns. Jika `@title` assign berubah, kemudian LiveView akan mengeksekusi `expand_title(@title)` dan mengirim konten baru. Jika `@title` sama, tidak ada yang dieksekusi dan tidak ada yang dikirim.

Change tracking juga bekerja ketika mengakses field map/struct. ambil template ini:

```elixir
<div id={"user_#{@user_id}"}>
  <%= @user.name %>
</div>
```

Jika `@user.name` berubah tapi `@user.id` tidak, maka LiveView akan merender ulang hanya `@user.name` dan tidak akan mengeksekusi atau mengirim ulang `@user.id` sama sekali.

Change tracking juga bekerja ketika merender template lainnya sepanjang mereka juga `.heex` template

```elixir
<%= render "child_template.html", assings %>
```

atau ketika menggunakan function component

```elixir
<.show_name name={@user.name} />
```

fitur assign tracking juga menyiratkan bahwa kamu harus menghindari melakukan operasi langsung dalam template. Misalnya, jika anda melakukan query database di dalam templatemu:

```elixir
<%= for user <- Repo.all(User) do %>
  <%= user.name %>
<% end %>
```

Kemudian Phoenix tidak akan merender ulang section di atas, bahkan jika jumlah user di database berubah. Harusnya kamu perlu menyimpan users sebagai assign di LiveView sebelum merender template:

```elixir
assign(socket, :users, Repo.all(User))
```

Secara umum, data loading tidak seharusnya terjadi di dalam template, terlepas jika kamu menggunakan LiveView atau tidak. Perbedaannya adalah LiveView menerapkan praktik terbaik.

**Pitfalls**
Ada 2 jebakan umum yang perlu diingat ketika menggunakan template `~H` sigil atau `.heex` template di dalam LiveView.

Ketika menyangkut blok `do/end`, change tracking hanya didukung pada blok yang diberikan pada konstruksi dasar Elixir, seperti `if`, `case`, `for` dan sejenisnya. Jika blok `do/end` diberikan function library atau user function, seperti `content_tag`, change tracking tidak akan bekerja. Sebagai contoh, bayangkan template berikut ini yang merender `div`:

```elixir
<%= content_tag :div, id: "user_#{@id}" do %>
  <%= @name %>
  <%= @description %>
<% end %>
```

LiveView tidak tau apapun tenant `content_tag`, yang berarti seluruh `div` akan dikirim kapanpun assigns berubah. Untungnya, HEEx template menyediakan sintak yang bagus untuk building tags, Jadi ini jarang menggunakan `content_tag` di dalam `.heex` template:

```elixir
<div id={"user_#{@id}"}>
  <%= @name %>
  <%= @description %>
</div>
```

Jebatan berikutnya adalah berhubungan dengan variable. Karena cakupan variable, LiveView harus mendisable change tracking setiap kali variable digunakan di template, dengan exception variable yang diperkenalkan oleh Elixir basic `case`, `for` dan contruct blok lainnya. Oleh karena itu kamu harus menghindari kode seperti ini di LiveView template:

```elixir
<% some_var = @x + @y %>

<= some_var %>
```

Mending gunakan sebuah function:

```elixir
<%= sum(@x, @y) %>
```

Sama juga, jangan mendefinisikan variable di atas dari function `render`:

```elixir
def render(assigns) do
  sum = assignx.x + assigns.y

  ~H"""
  <%= sum %>
  """
end
```

Mending secara explisit hitung assign di LiveViewmu, di luar render:

```elixir
assign(socket, sum: socket.assigns.x + socket.assigns.y)
```

Secara umum, hinari mengakses variable di dalam LiveView, karena kode yang mengakses variable selalu dijalankan setiap render. Ini juga diaplikasikan ke variable `assigns`. Exceptionnya adalah variable yang diperkenalkan oleh blok construct Elixir. Sebagai contoh, mengakses `post` variable yang didefinisikan oleh comprehension di bawah ini berfungsi seperti yang diharapkan:

```elixir
<%= for post <= @posts do %>

<% end %>
```

Singkatnya:

1. Hindari mengoper block expression ke library dan function custom, mending menggunakan kemudahan di `HEEx` templates
2. Hindari mendefinisikan local variable, kecuali di dalam Elixir contruct.
