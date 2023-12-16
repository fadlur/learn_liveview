## Welcome

Selamat datang di dokumentasi Phoenix Liveview.

**What is LiveView?**
LiveView adalah process yang menerima events, update statenya, dan merender update ke sebuah halaman sebagai diff.

Model programming liveView adalah deklaratif: Alih-alih mengatakan "setelah event X terjadi, ubah Y di halaman", event di LiveView adalah message reguler yang menyebabkan perubahan ke statenya, LiveView akan merender ulang bagian yang relevant dari template HTML dan mendorongnya ke browser, yang akan mengupdate dengan cara yang paling efisien.

LiveView state tidak lebih dari functional and immutable Elixir data structure. Event adalah message aplikasi internal (biasanya dipancarkan oleh `Phoenix.PubSub`) atau dikirim oleh client/browser.

LiveView dirender pertama kali secara statis sebagai bagian dari request HTTP regular, yang menyediakan waktu cepat untuk "First Meaningful Paint", untuk membantu search engine and indexing. Kemudian koneksi terus menerus dijalankan antara client dan server. Ini memungkinkan aplikasi LiveView untuk bereaksi lebih cepat terhadap user event sehingga hanya sedikit pekerjaan yang perlu dilakukan dan data yang dikirim lebih sedikit dibandingkan _stateless_ request yang harus melakukan otentikasi, decode, load dan encode data di setiap request.

**Example**

LiveView disertakan secara default di Aplikasi Phoneix. Oleh karena itu, untuk menggunakan LiveView, harus sudah menginstall phoenix dan membuat aplikasi pertamamu. Jika belum, cek [Phoenix's installation guide](https://hexdocs.pm/phoenix/installation.html).

Perilaku dari LiveView diuraikan oleh sebuah module yang mengimplement sebuah rangkaian dari function sebagai callbacks. Mari lihat contoh berikut:

```elixir
defmodule LearnLiveviewWeb.ThermostatLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    Current temperature: <%= @temperature %>°F
    <br />
    <button phx-click="inc_temperature">+</button>
    <button phx-click="dec_temperature">-</button>
    """
  end

  def mount(_params, _session, socket) do
    temperature = 70 # Let's assume a fixed temperatur for now
    {:ok, assign(socket, :temperature, temperature)}
  end

  def handle_event("inc_temperature", _params, socket) do
    {:noreply, update(socket, :temperature, &(&1 + 1))}
  end

  def handle_event("dec_temperature", _params, socket) do
    {:noreply, update(socket, :temperature, &(&1 - 1))}
  end

end

```

Modul di atas mendefinisikan 3 function (mereka adalah callback yang dibutuhkan oleh LiveView). Yang pertama adalah `render/1`, yang menerima socket `assigns` dan bertanggung jawab untuk mengembalikan konten yang akan dirender di halaman. Kita menggunakan `~H` sigil untuk mendefinisikan sebuah HEEx template.

Data yang digunakan untuk rendering datang dari `mount` callback. `mount` callback dipanggil ketika LiveView mulai. Di dalamnya kamu dapat mengakses request parameter, membaca informasi yang disimpan di session (umumnya informasi yang mengidentifikasi user saat ini), dan sebuah socket. Socket adalah di mana kita menyimpan semua state, termasuk assigns. `mount` memproses ke assign sebuah default temperature ke socket. karena elixir data struktur adalah immutable, LiveView API sering menerima socket dan mengembalikan sebuah socket yang telah diupdate. Kemudian kita mengembalikan `{:ok, socket}` to memberitahu bahwa kita mampu untuk _mount_ LiveView dengan sukses. Setelah `mount`, LiveView akan merender halaman dengan value dari `assigns` dan mengirimnya ke client.
Jika kamu melihat HTML yang dirender, kamu akan melihat ada sebuah button dengan `phx-click` attribut. Ketika button diklik, sebuah `inc_temperature` event dikirim ke server, yang dicocokkan dan dihandle oleh `handle_event` callback. Callback ini mengupdate socket dan mengembalikan `{:noreply, socket}` dengan socket yang telah diupdate. `handle_*` callback di LiveView (dan di elixir umumnya) dipanggil berdasarkan beberapa action, di kasus ini, user mengklik button. `{:noreply, socket}` kembalian berarti tidak ada tambahan balasan yang dikirim ke browser, hanya sebuah versi baru dari halaman yang dirender. LiveView kemudian menghitung diffs dan mengirim mereka ke client.

Sekarang kita siap untuk merender LiveView kita. Kamu dapat menyajikan LiveVie secara langsung dari router:

```elixir
defmodule LearnLiveviewWeb.Router do
  use LearnLiveviewWeb, :router
  import Phoenix.LiveView.Router
...

  scope "/", LearnLiveviewWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/thermostat", ThermostatLive
  end
  ...
end
```

Setelah LiveView dirender, sebuah reguler HTML response dikirim. Di app.js file, kita akan menemukan:

```elixir
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
liveSocket.connect()
```

Sekarang javascript client akan terhubung via WebSocket dan `mount/3` akan dipanggil di dalam sebuah spawned LiveView process.

**Parameter and Session**
Mount callback menerima 3 argument: request parameter, session dan socket.

Parameter dapat digunakan untuk membaca informasi dari URL, sebagai contoh, asumsikan punya sebuah module `Thermostat`didefinisikan di suatu tempat yang dapat membaca informasi ini berdasarkan house name, dapat ditulis begini.

Buat module Thermostat dulu:

```elixir
defmodule LearnLiveview.Thermostat do
  def get_house_reading(house) do
    String.to_integer(house)
  end
end

```

Function Mount kita update menjadi:

```elixir
  def mount(%{"house" => house}, _session, socket) do
    temperature = Thermostat.get_house_reading(house) # Let's assume a fixed temperatur for now
    {:ok, assign(socket, :temperature, temperature)}
  end
```

Kemudian di router:

```elixir
live "/thermostat/:house", ThermostatLive
```

Session menerima informasi dari sebuah signed (atau encrypted) cookie. Ini adalah di mana kamu dapat menyimpan informasi otentikasi, seperti `current_user_id`:

```elixir
def mount(_params, %{"current_user_id" => user_id}, socket) do
  temperature = Thermostat.get_user_reading(user_id)
  {:ok, assign(socket, :temperature, temperature)}
end
```

> Phoenix comes with built-in authentication generators. See [mix phx.gen.auth](https://hexdocs.pm/phoenix/1.6.15/Mix.Tasks.Phx.Gen.Auth.html)

Seringkali, di praktiknya, kamu akan melihat keduanya:

```elixir
def mount(%{"house" => house}, %{"current_user_id" => user_id}, socket) do
  temperature = Thermostat.get_house_reading(user_id, house)
  {:ok, assign(socket, :temperature, temperature)}
end
```

Dengan kata lain, kamu ingin membaca informasi tentang sebuah house yang diberikan, sepanjang user mempunyai akses ke situ.

**Bindings**
Phoenix mendukung DOM element bindings untuk client-server interaction. Sebagai contoh, untuk bereaksi terhadap click di sebuah button, kamu dapat merender element:

```elixir
<button phx-click="inc_temperature">+</button>
```

Kemudian di server, semua LiveView binding dihandle dengan `handle_event/3` callback:

```elixir
def handle_event("inc_temperature", _value, socket) do
  {:noreply, update(socket, :temperature, &(&1 + 1))}
end
```

Untuk mengupdate UI state, sebagai contoh, untuk membuka dan membuka dropdown, switch tabs dll. LiveView juga mendukung JS commands (`Phoenix.LiveView.JS`), yang mengeksekusi secara langsung di client tanpa mengakses (reach) server. Lebih lanjut buka, [our binding page](https://hexdocs.pm/phoenix_live_view/bindings.html) untuk list lengkapnya dari semua LiveView Binding [javascript interoperability guide](https://hexdocs.pm/phoenix_live_view/js-interop.html)

LiveView mempunyai built-in support untuk form, termasuk upload dan association management. Lihat [Phoenix.component.form/1](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#form/1) sebagai awalan dan [Phoenix.Component.inputs_for/1](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#inputs_for/1) untuk bekerja dengan associations. [Uploads](https://hexdocs.pm/phoenix_live_view/uploads.html) dan [Form bindings](https://hexdocs.pm/phoenix_live_view/form-bindings.html) menyediakan informasi tentang feature tingkat lanjut.

**Navigation**
LiveView menyediakan functionality untuk navigasi halaman menggunakan [browser's pushState API](https://developer.mozilla.org/en-US/docs/Web/API/History_API). Dengan live navigation, halaman diupdate tanpa reload full halaman.

Kamu dapat _patch_ LiveView saat ii, mengupdate URLnya atau navigasi ke sebuah LiveView baru. Kamu dapat belajar lebih lanjut di [Live Navigation guide](https://hexdocs.pm/phoenix_live_view/live-navigation.html)

**Generator**

Phoenix v1.6 dan versi setelahnya menyertakan code generator untuk LiveView. Jika kamu ingin melihat sample bagaimana struktur aplikasimu, dari database semua ke LiveView, jalankan perintah berikut:

```elixir
mix phx.gen.live Blog Post posts title:string body:text
```

Untuk informasi lebih lanjut, jalankan `mix help phx.gen.live`

Untuk otentikasi, dengan built-in LiveView support, jalankan `mix phx.gen.auth Account User users`

**Compartmentalize state, markup, dan events in LiveView**

LiveView mendukung 2 mekanisme ekstensi: function component, disediakan oleh `HEEx` template, dan stateful components.

Function components adalah function apapun yang menerima sebuah map assigns, mirip dengan `render(assigns)` di LiveView kita, dan mengembalikan sebuah `~H` template :

```elixir
def weather_greeting(assigns) do
  ~H"""
  <div title="My div" class={@class}>
    <p>Hello <%= @name %></p>
    <MyApp.Weather.city name="Kraków"/>
  </div>
  """
end
```

Kamu dapat mempelajari lebih lanjut tentang function component di modul [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html). pada akhirnya, mereka adalah mekanisme yang sangat berguna untuk reuse markup di LiveView.

Namun, kadang-kadang perlu mengkotak-kotakkan (compartmentalize) atau reuse lebih dari sekadar markup. Mungkin kamu ingin memindahkan sebagian state atau bagian dari event di LiveView ke module terpisah. untuk kasus ini, LiveView menyediakan [Phoenix.LiveComponent](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html), yang dirender menggunakan [live_component/1](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#live_component/1)

```elixir
<.live_component module={UserComponent} id={user.id} user={user} />
```

Component mempunyai `mount/3` mereka sendiri dan `handle_event/3` callback, begitu juga state mereka sendiri dengan change tracking support. Component sangat ringan seperti mereka "run" di process yang sama dengan parent `LiveView`, Bagaimanapun, ini berarti sebuah error di component akan menyebabkan seluruh view gagal dirender. Lihat [Phoenix.LiveComponent](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html) untuk ikhtisar lengkap tentang component.

Akhirnya, jika kamu ingin isolasi sepenuhnya antar bagian dari sebuah LiveView, kamu dapat selalu merender sebuah LiveView di dalam LIveView lainnya dengan memanggil [live_render/3](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#live_render/3). Child LiveView berjalan di process terpisah dari parent, dengan callbacknya sendiri. Jika sebuah child LiveView crashes, itu tidak akan mempengaruhi parent. Jika parent crash, semua child LiveView akan dimatikan.

Ketika merender sebuah child LiveView, `:id` option diperlukan untuk secara unik mengidentifikasi child LiveView. Sebuah child LiveView hanya akan merender dan mounted sekali waktu, ID yang disediakan tidak berubah. Untuk memakasa child LiveView untuk re-mount dengan session data, sebuah ID baru harus disediakan.

Mengingat LiveView berjalan di processnya sendiri adalah tool yang sangat sempurna untuk membuat UI Element yang terisolasi sepenuhnya, tapi ini adalah abstraksi yang sedikit mahal jika yang anda inginkan adalah mengkotak-kotakkan markup atau event (atau keduanya).

singkatnya:

- Gunakan [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) untuk mengkotak-kotakkan (compartmentalize)/reuse markup
- Gunakan [Phoenix.LiveComponent](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html) untuk mengkotak-kotakkan state, markup dan event
- Gunakan [Phoenix.LiveView](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html) bersarang untuk mengkotak-kotakkan state, markup, event dan error isolation.
