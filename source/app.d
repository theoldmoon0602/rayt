import std.stdio;
import std.format;
import std.math;
import std.random;
import std.parallelism;
import std.range;
import std.typecons;
import std.meta;
import std.algorithm;

import v;

struct Sphere
{
  public:
    V p;
    double r;
    V R;  //reflectance
    V Le;  // illuminance

    Hit* intersection(Ray ray, double from, double to)
    {
      import std.math : sqrt;

      V op = p - ray.o;  // 光線の原点から球の中心へのベクトルOP
      auto b = dot(op, ray.d);  // 光線の方向成分を取り出す
      auto det = b*b  - dot(op, op) + r*r;
      if (det < 0) {
        return null;
      }

      auto t = b - sqrt(det);
      if (from < t && t < to) {
        return new Hit(t, V(), V(), this);
      }
      
      t = b + sqrt(det);
      if (from < t && t < to) {
        return new Hit(t, V(), V(), this);
      }

      return null;
    }
}

struct Ray
{
  public:
    V o;
    V d;
}

struct Hit
{
  public:
    double t;
    V p;
    V n;
    Sphere s;
}

struct Scene
{
  public:
    Sphere[] spheres = [
      // Sphere( V(-0.5, 0, 0), 1, V(1, 0, 0)),
      // Sphere( V(0.5, 0, 0), 1, V(0, 0, 1)),
      
      Sphere( V(1e5+1,40.8,81.6)  , 1e5 , V(0.75, 0.25, 0.25) ),
      Sphere( V(-1e5+99,40.8,81.6), 1e5 , V(0.25, 0.25, 0.75) ),
      Sphere( V(50,40.8,1e5)      , 1e5 , V(0.75, 0.75, 0.75) ),
      Sphere( V(50,1e5,81.6)      , 1e5 , V(0.75, 0.75, 0.75) ),
      Sphere( V(50,-1e5+81.6,81.6), 1e5 , V(0.75, 0.75, 0.75) ),
      Sphere( V(27,16.5,47)       , 16.5, V(1) ),
      Sphere( V(73,16.5,78)       , 16.5, V(1) ),
      Sphere( V(50,681.6-.27,81.6), 600 , V(0), V(12) ),
    ];

    Hit* intersection(scope const(Ray) r, double from, double to)
    {
      Hit* hit;
      foreach (sphere; spheres) {
        auto h = sphere.intersection(r, from, to);
        if (!h) { continue; }
        hit = h;
        to = hit.t;
      }
      
      if (hit) {
        auto s = hit.s;
        hit.p = r.o + r.d * hit.t;
        hit.n = (hit.p - s.p) / s.r;
      }
      return hit;
    }
}


int tonemap(double v)
{
  import std.algorithm;
  import std.math;
  
  return min(max(cast(int)(pow(v, 1/2.2)*255), 0), 255);
}

Tuple!(V, V) tangentSpace(const(V) n) {
    auto s = copysign(1, n.z);
    auto a = -1 / (s + n.z);
    auto b = n.x*n.y*a;
    return tuple(
        V(1 + s * n.x*n.x*a,s*b,-s * n.x),
        V(b,s + n.y*n.y*a,-n.y)
    );
}

void main()
{
  const uint w = 1200;
  const uint h = 800;

  const double fov = 30 * PI / 180;
  const double aspect = cast(double)(w)/h;

  auto data = new V[](h * w);

  // camera
  // const V eye = V(5,5,5);
  // const V center = V(0,0,0);
  // const V up = V(0, 1, 0);
  // camera
  const V eye = V(50,52,295.6);
  const V center = eye + V(0,-0.0462612,-1);
  const V up = V(0, 1, 0);

  // camera basis
  const auto wE = (eye-center).normalize;
  const auto uE = cross(up, wE).normalize;
  const auto vE = cross(wE, uE);

  Scene scene;
  const spp = 50;
  const depth = 10;
  
  foreach (i; iota(w*h).parallel) {
    auto x = i %w;
    auto y = h - i / w;
    
    foreach (j; iota(spp).parallel) {
      Ray r;
      r.o = eye;
      r.d = (() {
          const double tf = tan(fov * 0.5);
          const double rpx = 2.0 * (x + uniform(0.0, 1.0)) / w - 1;
          const double rpy = 2.0 * (y + uniform(0.0, 1.0)) / h - 1;
          const V w = V(aspect*tf*rpx, tf*rpy, -1).normalize();
          return uE*w.x + vE*w.y + wE*w.z;
          })();

      V L;
      V th = V(1);

      // 光の反射を追いかけてるらしいぞ
      foreach (_; 0..depth) {
        auto hit = scene.intersection(r, 1e-4, 1e10);
        if (!hit) { break; }
        L = L + th * hit.s.Le;

        // わからーん！！
        r.o = hit.p;
        r.d = (() {
          auto n = (dot(hit.n, -r.d) > 0) ? hit.n : -hit.n;
          V u,  v;
          AliasSeq!(u ,v) = tangentSpace(n);
          auto d = (() {
              auto r = sqrt(uniform(0.0, 1.0));
              auto t = 2 * PI * uniform(0.0, 1.0);
              auto x = r * cos(t);
              auto y = r * sin(t);
              return V(x, y, sqrt(max(0.0, 1 - x*x - y*y)));
          })();


          // ワールド座標に変換しているっぽい
          return u*d.x + v*d.y + n*d.z;
        })();
        th = th * hit.s.R;
        if (max(th.x, th.y, th.z) == 0) {
          break;
        }
      }
      data[i] = data[i] + L / spp;
    }
  }

  File f = File("result.ppm", "w");
  scope(exit) f.close();

  f.write("P3\n", "%d %d\n".format(w, h), "255\n");
  foreach (d; data) {
      f.writeln("%d %d %d".format(
            tonemap(d.x),
            tonemap(d.y),
            tonemap(d.z)
            ));
  }
}
