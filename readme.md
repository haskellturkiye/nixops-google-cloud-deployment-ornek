# Nixops ile GoogleCloud Deployment örneği

Etkinlik videosuna şuradan ulaşabilirsiniz: [https://youtu.be/VIBPfXmkvr8](https://youtu.be/VIBPfXmkvr8)

İlk olarak google cloud developer console üzerinden hizmet hesabı (service account) oluşturmalısınız.

Daha sonra bu hizmet hesabına bir p12 formatında gizli anahtar tanımlayıp bunu indirmelisiniz.

İndirdiğiniz dosyayı aşağıdaki komut ile pem formatına dönüştürmelisiniz.

`openssl pkcs12 -in [DOSYA ADI] -passin pass:notasecret -nodes -nocerts | openssl rsa -out pkey.pem`

Ardından `default.nix` dosyasındaki credentials ayarlarını kendinize göre güncelleyin. `project` değeri google cloud üzerindeki proje adınız olacak. `serviceAccount` ayarı ise oluşturduğunuz hizmet hesabı olacak.

Artık `nixops create default.nix -d projecadi` diyerek deployment tanımlamanızı nixops'a verebilirsiniz.

Demo uygulama içerisindeki `database_password` değerini ayarlamayı unutmayın.

`nixops set-args -d projecadi --argstr database_password "123123"`

Artık uygulamanızı deploy edebilirsiniz;

`nixops deploy -d projecadi`

Deployment biterken GoogleCloud dahilindeki nixos imajında bulunan bir bugdan dolayı hata alabilirsiniz. Bu durumda makinalara tek tek bağlanarak aşağıdaki komutları çalıştırın.

`nixops ssh -d projeadi makinaadi`

Buradaki makinaadi değeri default.nix dosyasındaki `backend1`,`backend2`,`database` gibi değişken isimleri.

time sync error fix
https://github.com/NixOS/nixpkgs/issues/31540

`rm -rf {/var/lib/systemd/timesync,/var/lib/private/systemd/timesync}`


