import SwiftUI

/// Brand icon descriptor — either an SVG asset (Simple Icons) or a
/// fallback SF Symbol when the brand isn't covered. The View layer
/// uses `BrandIconView` to render either kind uniformly.
struct BrandIconDescriptor: Equatable {
    enum Source: Equatable {
        case asset(String)
        case sfSymbol(String)
    }
    let source: Source
    let tint: Color
}

/// Lookup table from preset id (`PresetGroups`) and process names to
/// brand visuals. Tints are taken from each brand's official color
/// where they read well on a dark surface; brands whose mark is
/// black-on-white (Next.js, Remix, Rust, Bun, Deno, …) are forced
/// to the warm-ink color so they stay visible on the popover gradient.
enum BrandIcons {

    // Brand colors that read well on Theme.surfaceLo / surfaceHi.
    // Hex values from Simple Icons brand metadata.
    private static let inkOnDark    = Theme.ink                                       // #e8e4da
    private static let cReact       = Color(red:  97/255, green: 218/255, blue: 251/255) // #61DAFB
    private static let cVite        = Color(red: 100/255, green: 108/255, blue: 255/255) // #646CFF
    private static let cAstro       = Color(red: 188/255, green:  82/255, blue: 238/255) // #BC52EE
    private static let cSvelte      = Color(red: 255/255, green:  62/255, blue:   0/255) // #FF3E00
    private static let cNuxt        = Color(red:   0/255, green: 220/255, blue: 130/255) // #00DC82
    private static let cRubyOnRails = Color(red: 211/255, green:   0/255, blue:   1/255) // #D30001
    private static let cSpring      = Color(red: 109/255, green: 179/255, blue:  63/255) // #6DB33F
    private static let cLaravel     = Color(red: 255/255, green:  45/255, blue:  32/255) // #FF2D20
    private static let cDotnet      = Color(red: 129/255, green:  75/255, blue: 219/255) // #814BDB (lifted)
    private static let cGo          = Color(red:   0/255, green: 173/255, blue: 216/255) // #00ADD8
    private static let cPostgres    = Color(red:  92/255, green: 130/255, blue: 219/255) // #5C82DB (lifted from #4169E1)
    private static let cMySQL       = Color(red:   0/255, green: 137/255, blue: 200/255)
    private static let cMongo       = Color(red:  71/255, green: 162/255, blue:  72/255) // #47A248
    private static let cRedis       = Color(red: 220/255, green:  56/255, blue:  45/255) // #DC382D
    private static let cElastic     = Color(red:   0/255, green: 191/255, blue: 165/255) // teal lift
    private static let cCassandra   = Color(red:  18/255, green: 135/255, blue: 177/255) // #1287B1
    private static let cCouchDB     = Color(red: 228/255, green:  37/255, blue:  40/255) // #E42528
    private static let cInflux      = Color(red:  34/255, green: 173/255, blue: 246/255) // #22ADF6
    private static let cNeo4j       = Color(red:  69/255, green: 129/255, blue: 195/255) // #4581C3
    private static let cSupabase    = Color(red:  63/255, green: 207/255, blue: 142/255) // #3FCF8E
    private static let cFirebase    = Color(red: 255/255, green: 167/255, blue:  38/255) // amber-orange
    private static let cAppwrite    = Color(red: 253/255, green:  54/255, blue: 110/255) // #FD366E
    private static let cRabbitMQ    = Color(red: 255/255, green: 102/255, blue:   0/255) // #FF6600
    private static let cDocker      = Color(red:  36/255, green: 150/255, blue: 237/255) // #2496ED
    private static let cKubernetes  = Color(red:  50/255, green: 108/255, blue: 229/255) // #326CE5
    private static let cNode        = Color(red:  95/255, green: 160/255, blue:  78/255) // #5FA04E
    private static let cPython      = Color(red:  55/255, green: 118/255, blue: 171/255) // #3776AB
    private static let cPHP         = Color(red: 119/255, green: 123/255, blue: 180/255) // #777BB4
    private static let cJava        = Color(red: 237/255, green: 139/255, blue:   0/255) // #ED8B00
    private static let cMinIO       = Color(red: 195/255, green:  39/255, blue:  43/255) // C3272B
    private static let cFlask       = Color(red: 220/255, green: 220/255, blue: 220/255)

    /// Preset id (e.g. `"preset.nextjs"`) → descriptor.
    static func forPreset(_ id: String) -> BrandIconDescriptor {
        switch id {
        case "preset.nextjs":    return .init(source: .asset("Brands/nextdotjs"),    tint: inkOnDark)
        case "preset.react":     return .init(source: .asset("Brands/react"),         tint: cReact)
        case "preset.vite":      return .init(source: .asset("Brands/vite"),          tint: cVite)
        case "preset.tanstack":  return .init(source: .sfSymbol("square.stack.3d.up.fill"), tint: Theme.amber)
        case "preset.astro":     return .init(source: .asset("Brands/astro"),         tint: cAstro)
        case "preset.svelte":    return .init(source: .asset("Brands/svelte"),        tint: cSvelte)
        case "preset.nuxt":      return .init(source: .asset("Brands/nuxt"),          tint: cNuxt)
        case "preset.remix":     return .init(source: .asset("Brands/remix"),         tint: inkOnDark)

        case "preset.express":   return .init(source: .asset("Brands/express"),       tint: inkOnDark)
        case "preset.django":    return .init(source: .asset("Brands/django"),        tint: inkOnDark)
        case "preset.flask":     return .init(source: .asset("Brands/flask"),         tint: cFlask)
        case "preset.rails":     return .init(source: .asset("Brands/rubyonrails"),   tint: cRubyOnRails)
        case "preset.spring":    return .init(source: .asset("Brands/spring"),        tint: cSpring)
        case "preset.laravel":   return .init(source: .asset("Brands/laravel"),       tint: cLaravel)
        case "preset.dotnet":    return .init(source: .asset("Brands/dotnet"),        tint: cDotnet)
        case "preset.gohttp":    return .init(source: .asset("Brands/go"),            tint: cGo)
        case "preset.actix":     return .init(source: .asset("Brands/rust"),          tint: inkOnDark)

        case "preset.postgres":      return .init(source: .asset("Brands/postgresql"),     tint: cPostgres)
        case "preset.mysql":         return .init(source: .asset("Brands/mysql"),          tint: cMySQL)
        case "preset.mongo":         return .init(source: .asset("Brands/mongodb"),        tint: cMongo)
        case "preset.redis":         return .init(source: .asset("Brands/redis"),          tint: cRedis)
        case "preset.elasticsearch": return .init(source: .asset("Brands/elasticsearch"),  tint: cElastic)
        case "preset.cassandra":     return .init(source: .asset("Brands/apachecassandra"), tint: cCassandra)
        case "preset.couchdb":       return .init(source: .asset("Brands/apachecouchdb"),  tint: cCouchDB)
        case "preset.influx":        return .init(source: .asset("Brands/influxdb"),       tint: cInflux)
        case "preset.neo4j":         return .init(source: .asset("Brands/neo4j"),          tint: cNeo4j)

        case "preset.supabase":  return .init(source: .asset("Brands/supabase"),      tint: cSupabase)
        case "preset.firebase":  return .init(source: .asset("Brands/firebase"),      tint: cFirebase)
        case "preset.appwrite":  return .init(source: .asset("Brands/appwrite"),      tint: cAppwrite)

        case "preset.kafka":     return .init(source: .asset("Brands/apachekafka"),   tint: inkOnDark)
        case "preset.rabbitmq":  return .init(source: .asset("Brands/rabbitmq"),      tint: cRabbitMQ)
        case "preset.nats":      return .init(source: .sfSymbol("dot.radiowaves.up.forward"), tint: Theme.cyan)

        case "preset.docker":    return .init(source: .asset("Brands/docker"),        tint: cDocker)
        case "preset.kubernetes":return .init(source: .asset("Brands/kubernetes"),    tint: cKubernetes)
        case "preset.minio":     return .init(source: .asset("Brands/minio"),         tint: cMinIO)
        case "preset.mailhog":   return .init(source: .sfSymbol("envelope.fill"),     tint: Theme.amberSoft)

        default:
            return .init(source: .sfSymbol("rectangle.connected.to.line.below"), tint: Theme.inkFaint)
        }
    }

    /// Process name → descriptor. Used in popover rows for ports that
    /// don't match a pinned preset. Falls back to `nil` when we don't
    /// know the brand (the row simply omits the icon).
    static func forProcess(
        processName: String,
        framework: FrameworkHint?
    ) -> BrandIconDescriptor? {
        // Framework wins — that's the most specific signal.
        if let hint = framework, let frameworkIcon = forFramework(hint) {
            return frameworkIcon
        }
        let lower = processName.lowercased()
        switch lower {
        // Runtimes
        case "node":                    return .init(source: .asset("Brands/nodedotjs"),  tint: cNode)
        case "deno":                    return .init(source: .asset("Brands/deno"),       tint: inkOnDark)
        case "bun":                     return .init(source: .asset("Brands/bun"),        tint: inkOnDark)
        case "python", "python3":       return .init(source: .asset("Brands/python"),     tint: cPython)
        case "ruby":                    return .init(source: .asset("Brands/ruby"),       tint: cRubyOnRails)
        case "java":                    return .init(source: .asset("Brands/openjdk"),    tint: cJava)
        case "php":                     return .init(source: .asset("Brands/php"),        tint: cPHP)
        case "dotnet":                  return .init(source: .asset("Brands/dotnet"),     tint: cDotnet)

        // Databases (process names from lsof)
        case "postgres", "postgresql", "postmaster":
                                        return .init(source: .asset("Brands/postgresql"),     tint: cPostgres)
        case "mysqld", "mysql", "mariadbd":
                                        return .init(source: .asset("Brands/mysql"),          tint: cMySQL)
        case "mongod":                  return .init(source: .asset("Brands/mongodb"),        tint: cMongo)
        case "redis-server", "redis":   return .init(source: .asset("Brands/redis"),          tint: cRedis)
        case "elasticsearch", "elastic":return .init(source: .asset("Brands/elasticsearch"),  tint: cElastic)
        case "cassandra":               return .init(source: .asset("Brands/apachecassandra"), tint: cCassandra)
        case "couchdb":                 return .init(source: .asset("Brands/apachecouchdb"),  tint: cCouchDB)
        case "influxd":                 return .init(source: .asset("Brands/influxdb"),       tint: cInflux)
        case "neo4j":                   return .init(source: .asset("Brands/neo4j"),          tint: cNeo4j)
        case "memcached":               return .init(source: .sfSymbol("memorychip"),         tint: Theme.cyan)

        default: return nil
        }
    }

    private static func forFramework(_ hint: FrameworkHint) -> BrandIconDescriptor? {
        switch hint {
        case .nextjs:     return .init(source: .asset("Brands/nextdotjs"), tint: inkOnDark)
        case .vite:       return .init(source: .asset("Brands/vite"),      tint: cVite)
        case .cra:        return .init(source: .asset("Brands/react"),     tint: cReact)
        case .rails:      return .init(source: .asset("Brands/rubyonrails"), tint: cRubyOnRails)
        case .django:     return .init(source: .asset("Brands/django"),    tint: inkOnDark)
        case .flask:      return .init(source: .asset("Brands/flask"),     tint: cFlask)
        case .express:    return .init(source: .asset("Brands/express"),   tint: inkOnDark)
        case .spring:     return .init(source: .asset("Brands/spring"),    tint: cSpring)
        case .rustRocket, .rustActix:
                          return .init(source: .asset("Brands/rust"),      tint: inkOnDark)
        case .goStdlib:   return .init(source: .asset("Brands/go"),        tint: cGo)
        case .nuxt:       return .init(source: .asset("Brands/nuxt"),      tint: cNuxt)
        case .astro:      return .init(source: .asset("Brands/astro"),     tint: cAstro)
        case .svelte:     return .init(source: .asset("Brands/svelte"),    tint: cSvelte)
        case .remix:      return .init(source: .asset("Brands/remix"),     tint: inkOnDark)
        case .unknown:    return nil
        }
    }
}
