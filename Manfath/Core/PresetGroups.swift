import Foundation

/// Curated catalog of common dev-stack port groups. Each preset maps
/// to a `PortGroup` the user can pin with a single toggle. IDs are
/// stable strings so the on/off state survives across upgrades.
///
/// Add presets by extending `all`. Order here is the order rendered
/// in Settings.
public enum PresetGroups {

    public struct Preset: Identifiable, Hashable, Sendable {
        public let id: String           // stable: "preset.nextjs", "preset.postgres", …
        public let name: String         // user-facing label (English source)
        public let ports: [UInt16]
        public let ranges: [PortRange]

        public init(id: String, name: String, ports: [UInt16] = [], ranges: [PortRange] = []) {
            self.id = id
            self.name = name
            self.ports = ports
            self.ranges = ranges
        }
    }

    public static let all: [Preset] = [
        // Frontend frameworks
        .init(id: "preset.nextjs",   name: "Next.js",          ports: [3000, 3001]),
        .init(id: "preset.react",    name: "React (CRA)",      ports: [3000]),
        .init(id: "preset.vite",     name: "Vite",             ports: [5173, 5174]),
        .init(id: "preset.tanstack", name: "TanStack Start",   ports: [3000, 4000]),
        .init(id: "preset.astro",    name: "Astro",            ports: [4321]),
        .init(id: "preset.svelte",   name: "SvelteKit",        ports: [5173, 4173]),
        .init(id: "preset.nuxt",     name: "Nuxt",             ports: [3000, 24678]),
        .init(id: "preset.remix",    name: "Remix",            ports: [3000, 8002]),

        // Backend frameworks
        .init(id: "preset.express",  name: "Express / Fastify", ports: [3000, 4000, 5000]),
        .init(id: "preset.django",   name: "Django",            ports: [8000]),
        .init(id: "preset.flask",    name: "Flask",             ports: [5000, 8000]),
        .init(id: "preset.rails",    name: "Rails",             ports: [3000, 3001]),
        .init(id: "preset.spring",   name: "Spring Boot",       ports: [8080, 8081]),
        .init(id: "preset.laravel",  name: "Laravel",           ports: [8000, 8001]),
        .init(id: "preset.dotnet",   name: ".NET",              ports: [5000, 5001, 7000, 7001]),
        .init(id: "preset.gohttp",   name: "Go (net/http)",     ports: [8080, 8888]),
        .init(id: "preset.actix",    name: "Rust (Actix/Rocket)", ports: [8000, 8080]),

        // Databases
        .init(id: "preset.postgres",      name: "PostgreSQL",   ports: [5432, 5433]),
        .init(id: "preset.mysql",         name: "MySQL / MariaDB", ports: [3306, 3307]),
        .init(id: "preset.mongo",         name: "MongoDB",      ports: [27017, 27018, 27019]),
        .init(id: "preset.redis",         name: "Redis",        ports: [6379, 6380]),
        .init(id: "preset.elasticsearch", name: "Elasticsearch", ports: [9200, 9300]),
        .init(id: "preset.cassandra",     name: "Cassandra",    ports: [9042, 7000, 7001, 9160]),
        .init(id: "preset.couchdb",       name: "CouchDB",      ports: [5984]),
        .init(id: "preset.influx",        name: "InfluxDB",     ports: [8086, 8088]),
        .init(id: "preset.neo4j",         name: "Neo4j",        ports: [7474, 7687]),

        // Platform / BaaS
        .init(id: "preset.supabase", name: "Supabase (local)",
              ports: [], ranges: [PortRange(min: 54321, max: 54324)]),
        .init(id: "preset.firebase", name: "Firebase Emulators",
              ports: [4000, 4400, 4500, 8080, 9000, 9099, 5001, 9199]),
        .init(id: "preset.appwrite", name: "Appwrite",         ports: [80, 443, 8080]),

        // Messaging / streaming
        .init(id: "preset.kafka",    name: "Kafka",            ports: [9092, 2181, 9093]),
        .init(id: "preset.rabbitmq", name: "RabbitMQ",         ports: [5672, 15672]),
        .init(id: "preset.nats",     name: "NATS",             ports: [4222, 8222]),

        // Tooling
        .init(id: "preset.docker",   name: "Docker dev range",
              ports: [], ranges: [PortRange(min: 8000, max: 8999)]),
        .init(id: "preset.kubernetes", name: "Kubernetes API", ports: [6443, 8001, 10250]),
        .init(id: "preset.minio",    name: "MinIO",            ports: [9000, 9001]),
        .init(id: "preset.mailhog",  name: "Mailhog / Mailpit", ports: [1025, 8025]),
    ]

    public static func find(id: String) -> Preset? {
        all.first(where: { $0.id == id })
    }

    /// Build a fresh `PortGroup` from a preset. Caller appends to
    /// `settings.portGroups`.
    public static func makeGroup(from preset: Preset) -> PortGroup {
        PortGroup(
            name: preset.name,
            ports: preset.ports,
            ranges: preset.ranges,
            presetId: preset.id
        )
    }
}
