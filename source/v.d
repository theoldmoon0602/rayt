module v;

import std.format : format;

struct V
{
  public:
    double x = 0, y = 0, z = 0;

    this(double v) pure
    {
      x = v; y = v; z = v;
    }

    this(double x, double y, double z) pure
    {
      this.x = x;
      this.y = y;
      this.z = z;
    }

    pure V opUnary(string op)() if (op == "-")
    {
      return V(-x, -y, -z);
    }

    V opBinary(string op)(const(V) r) const pure
    {
      return mixin("V(x %1$s r.x, y %1$s r.y, z %1$s r.z)".format(op));
    }

    V opBinary(string op)(const(double) r) const pure
    {
      return mixin("V(x %1$s r, y %1$s r, z %1$s r)".format(op));
    }
}

double dot(const(V) l, const(V) r) pure
{
  return l.x*r.x + l.y*r.y + l.z*r.z;
}

V cross(const(V) l, const(V) r) pure
{
  return V(
      l.y*r.z - l.z*r.y,
      l.z*r.x - l.x*r.z,
      l.x*r.y - l.y*r.x
      );
}

V normalize(const(V) v) pure
{
  import std.math : sqrt;
  return v / sqrt(dot(v, v));
}
