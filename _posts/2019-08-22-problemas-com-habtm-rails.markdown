# Passos
  - OK = O que é HABTM
  - OK = Qual o problema que estavamos enfrentando
  - Solução Deferred
    - O que ele fazia e como usa-lo
    - Pq decidimos parar de usa-lo
  - Solução Caseira
    - O que ela faz e como usa-la


# Introdução
Depois eu faço
Todos os testes feitos foram com Rails versão 5.2.3 e 6.0.0

# O que é HABTM(has_and_belongs_to_many)
Na tradução livre da documentação do Rails é:

A associação ```has_and_belongs_to_many``` cria um relacionamento muitos-para-muitos com outro modelo. Em termos de banco de dados, ele associa duas classes através de uma tabela de junção intermediária que inclui chaves entrangeiras referentes a cada uma das classes.

"*The has_and_belongs_to_many association creates a many-to-many relationship with another model. In database terms, this associates two classes via an intermediate join table that includes foreign keys referring to each of the classes.*" [link para documentação](https://guides.rubyonrails.org/association_basics.html#has-and-belongs-to-many-association-reference)

# O problema
O problema que estávamos enfrentando é que por definição de implementação este tipo de relacionamento quando alterado (adicionado, removido, alterado, etc.) não se comporta como um atributo comum que espera o save do objeto para ser executado. Ele executa no mesmo instante que é "alterado". Isso significa em termos práticos que ao ser alterado o SQL é gerado sem dó nem piedade. Vou mostrar:

**Criei duas classes com os devidos relacionamentos feitos**

``` ruby
class Physician < ActiveRecord::Base
  has_and_belongs_to_many :patients
end

class Patient < ActiveRecord::Base
  has_and_belongs_to_many :physicians
end
```

**Aqui já havia feito a associação entre eles. Basicamente adicionei 2 pacientes no objeto médico médico**
``` ruby
(byebug) physician.patients
#<ActiveRecord::Associations::CollectionProxy [#<Patient id: 1, name: "Fulano1", created_at: "2019-08-22 14:19:12", updated_at: "2019-08-22 14:19:12">, #<Patient id: 2, name: "Fulano2", created_at: "2019-08-22 14:19:12", updated_at: "2019-08-22 14:19:12">]>
(byebug) physician.patient_ids
[1, 2]
```
**Agora possuo a intenção de remover os pacientes deste médico. Ok, bem simples, indico que vou remover a associação e mando salvar. Porém, olha a surpresinha:**
``` ruby
(byebug) physician.patient_ids = []
D, [2019-08-22T14:20:08.423007 #6] DEBUG -- :   Patient Load (0.3ms)  SELECT "patients".* FROM "patients" WHERE 1=0
D, [2019-08-22T14:20:08.426119 #6] DEBUG -- :    (0.1ms)  begin transaction
D, [2019-08-22T14:20:08.428890 #6] DEBUG -- :   Physician::HABTM_Patients Destroy (0.3ms)  DELETE FROM "patients_physicians" WHERE "patients_physicians"."physician_id" = ? AND "patients_physicians"."patient_id" IN (?, ?)  [["physician_id", 1], ["patient_id", 1], ["patient_id", 2]]
D, [2019-08-22T14:20:08.429591 #6] DEBUG -- :    (0.1ms)  commit transaction
[]
(byebug) physician.patient_ids
[]
(byebug) physician.save
true
```
**What?? Sim, o comando foi enviado para o banco de dados executar a SQL. E antes de salvar o objeto a associação já tinha sido removida.**

Isto, minhas amigas e meus amigos rola por conta desta linha de código aqui:

https://github.com/rails/rails/blob/v5.2.3/activerecord/lib/active_record/associations/association.rb#L73

ou

https://github.com/rails/rails/blob/v6.0.0/activerecord/lib/active_record/associations/association.rb#L92

O que este médido diz é: Define o destino dessa associação com o valor que estou recebendo(executando o SQL) e sinaliza ao objeto que foi feita a alteração. Sim, isso mesmo, ela não pergunta se existe alguma validação e nem guarda o valor em algum atrributo externo para validar o objeto antes de executar a atribuição do novo valor.

Neste caso isso é um enorme problema para quem precisa limitar esse comportamento. Pois esse tipo de coisa é contra instintivo se levarmos em conta o comportamento com a associação has_many(sem o through) ou a qualquer outro atributo, como nesse exemplo:

``` ruby
class Physician < ActiveRecord::Base
  has_and_belongs_to_many :patients

  validates :patients, presence: true
  # ou isso
  validates :patient_ids, presence: true
end
```

Claro, vai funcionar ao criar, vai impedir que o objeto sem essa associação seja salvo. Ao atualizar, vai até impedir de salvar, maas não vai impedir que seja removida as associações. :/

Ah, caso queira saber mais sobre o comportamento dessas associações, têm esses links oficiais do framework.

- https://api.rubyonrails.org/classes/ActiveRecord/Associations/CollectionProxy.html
- https://api.rubyonrails.org/classes/ActiveRecord/Associations/ClassMethods.html
- https://guides.rubyonrails.org/association_basics.html#methods-added-by-has-and-belongs-to-many-collection-objects

# Soluções
Bom vimos que nem tudo são flores, mas há sempre luz no fim do túnel rs.

No projeto que participo encontramos duas soluções para isso, depois de muitas pesquisas, lendo muita linha de código e de muita ajuda do stackoverflow (salve grande mestre rs). Essas soluções foram encontradas em tempos diferentes do projeto, dai vou mostrar agora pela ordem em que implementamos. Onde a segunda substitui a primeira solução dada. Mas isso não tira o mérito dela em ;)

## Deferring
[Deferring](https://github.com/robinroestenburg/deferring) é uma gem que basicamente sobrescreve o comportamento padrão adotado para as ```ActiveRecord_Associations_CollectionProxy``` que a classe que rege o comportamento das associações que estamos tratando.
Ela promete literalmente resolver nosso problema citado acima:

A gem deferring atrasará a criação de conexões(links) entre Person e Team até que a Person tenha sido salva com sucesso. (Tradução livre)

*The deferring gem will delay creating the links between Person and Team until the Person has been saved successfully.* [link da documentação](https://github.com/robinroestenburg/deferring#why-use-it)

Era isso que precisávamos! E funcionou muito bem! \o/

Vou me limitar aqui em falar do funcionamento detalhado desta gem porque você pode saber mais direto pelo link que coloquei acima que vai direto para documentação dela que está super bem explicada.

Então porque deixamos de usar e adotamos outra solução? Por alguns motivos bem própios, que são:

- A gem é um canhão de solução e na real precisávamos bem menos e usávamos, sei la, nem 1/4 do que ela oferecia.
- Estávamos numa vibe do projeto de enxugar código, principalmente código externo com soluções mais simples e que nos atendesse da mesma forma. (Minimalismo de código ahhaha).
- Também enfrentamos algumas dificuldades em formulários que exigiam muita validação de modelos diferentes unidos por um mesmo controller, enfim, algo muito específico de nosso projeto

Conclusão, a gem funciona muito bem para a proposta dela e a decisão de sairmos dela foi bem própria do projeto.

## Solução caseira

Depois de um tempo de pesquisa de como poderíamos contornar esse "problema" usando o que o rails já nos oferece com uso de por exemplo:

- autosave: false
- converter a associação ```has_and_belongs_to_many em has_many with through``` com validação no modelo intermediário
- usando os [callbacks de associação](https://guides.rubyonrails.org/association_basics.html#association-callbacks) como ```after_remove``` por exemplo

Bom já imaginam que nada disso resolveu rs. Mas ajudou a ver que o epicentro do problema era basicamente o uso do método:

```ruby
object.collection_assocition=([])
```
# Marcio, rever tudo daqui para baixo!!!!!!!!!!!!!

Sim, era basicamente esse ponto, só não queriamos que a associação recebesse um array vazio, nem direto pelo código e nem via tela.

É ai que entra o salvador stackoverflow rs, com essa question: https://stackoverflow.com/questions/38616387 Onde a proposta do cara é sobrescrever o método ```collection_association=(value)``` de modo a evitar o comportamento padrão e enviar um alerta para o modelo validar aquele atributo.

E, como base nisso e em que na vida nada se cria tudo se copia rs, fizemos a nossa solução. Como fazíamos o uso em muitas classes e fazíamos pequenas adaptações nas validações, optamos por fazer um concern, ficando assim:

```ruby
module HomemadeCollectionAssociation
  extend ActiveSupport::Concern

  included do
    def self.homemade_has_and_belongs_to_many(*args)
      collection_association = args.first.to_s
      options = args.extract_options!

      self.send(:has_and_belongs_to_many, *args, options)
      self.send(:generate_homemade_association_methods, collection_association)
    end

    private

    def self.generate_homemade_association_methods(collection_association)
      collection_association_and_collection_ids = [collection_association, "#{collection_association.singularize}_ids"]
      collection_association = collection_association_and_collection_ids.first
      collection_ids = collection_association_and_collection_ids.second

      collection_association_and_collection_ids.each do |target|
        self.instance_eval do
          self.send :attr_accessor, "#{target}_are_empty"
          self.send :attr_accessor, "#{target}_changed"

          private "#{target}_are_empty="
          private "#{target}_changed="

          define_method "#{target}_are_empty" do
            instance_variable_get("@#{target}_are_empty") || self.send(collection_ids).blank?
          end

          define_method "#{target}_changed" do
            instance_variable_get("@#{target}_changed") || false
          end

          define_method "#{target}=" do |value|
            value = value.reject(&:blank?)
            self.send("#{target}_changed=", self.send(collection_ids).sort != value.map { |v| self.send(target).is_a?(Array) ? v.to_i : v.id }.sort)

            if value.blank?
              self.send("#{target}_are_empty=", true)
            else
              self.send("#{target}_are_empty=", false)
              super(value)
            end
          end
        end
      end

      define_method "#{collection_association}_are_empty?" do
        self.send("#{collection_ids}_are_empty") || self.send("#{collection_association}_are_empty")
      end

      define_method "#{collection_association}_changed?" do
        self.send("#{collection_ids}_changed") || self.send("#{collection_association}_changed")
      end
    end
  end
end
```

Pensei em explicar cada linha, mas confesso que fiquei com preguiça(:P). Então vou fazer um pequeno resumo e mostrar a solução para as classes que usamos lá em cima.

Esse concern sobrescreve o método que falamos anteriormente ```collection_association=(value)``` e o ```collection_association_ids=(value)```. Caso o valor enviado seja um array vazio ou array de nulos ou até array de string vazia, não executa o comportamento padrão e avisa a classe que etamos tentando enviar um valor que vai deixar associação vazia. Faz também, dai, idependente de valor um aviso quando estamos alterando o valor da associação.

Esses avisos podem ser vistos através de dois métodos:

- ```collection_association_are_empty?```
- ```collection_association_changed?```

```ruby
    # For use it must use this method: `homemade_has_and_belongs_to_many :collection_association`
    # Methods for use: `collection_association_are_empty?` and `collection_association_changed?`
    # Hook: As this concern remove the default usability of `collection_association=([])` a mode of empty the associations is creating a callback `before_validation` and inside it use `self.collection_association.clear`
```

Resumo dado mas nada mais explica do que um exemplo, então la vai:

```ruby
    class Klass
      include HomemadeCollectionAssociation

      homemade_has_and_belongs_to_many :collection_klass

      before_validation :reset_collection_klass
      before_update :execute_this_method

      validate :collection_klass_must_not_be_empty

      def reset_collection_klass
        self.collection_klass.clear
      end

      def execute_this_method
        puts 'Running :)' if collection_klass_changed?
      end

      def collection_klass_must_not_be_empty
        errors.add(:collection_klass, :blank) if collection_klass.blank? || collection_klass_are_empty? # The use of method collection_klass.blank? is for complements the validation, in cases when the instance of object has collection_klass empty
      end
    end
```

To be continue....
https://github.com/marciojg/my-notes/blob/master/rails/problem_with_associations.md
